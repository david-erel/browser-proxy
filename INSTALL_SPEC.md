# BrowserProxy — Installation Specification

## Overview

BrowserProxy is a macOS background app (Cocoa, Go + Objective-C) that acts as the system's default browser. It intercepts all URL open events and routes them to Chrome or Firefox based on configurable rules. It runs as a persistent background process with no dock icon (`LSUIElement`).

## Prerequisites

- macOS (tested on macOS 15 / Sequoia)
- `defaultbrowser` CLI tool (`brew install defaultbrowser`) — used to set the default HTTP/HTTPS handler
- Go toolchain with CGO support (only needed if building from source)

## App Bundle Structure

The built `.app` bundle has this layout:

```
BrowserProxy.app/
└── Contents/
    ├── Info.plist          # App metadata, URL schemes, document types
    ├── MacOS/
    │   └── BrowserProxy    # Compiled Go+ObjC binary
    └── Resources/
        └── AppIcon.icns    # App icon (all sizes 16–1024px)
```

### Info.plist Key Entries

- `CFBundleIdentifier`: `com.daviderel.browserproxy`
- `CFBundleIconFile`: `AppIcon`
- `LSUIElement`: `true` (no dock icon, background-only app)
- `CFBundleURLTypes`: registers `http` and `https` URL schemes
- `CFBundleDocumentTypes`: declares support for `public.html`, `public.xhtml`, `public.url` (required for macOS to show the app in System Settings > Default web browser dropdown)

## Files and Directories Created

### 1. App binary — `/Applications/BrowserProxy.app/`

The entire `.app` bundle is copied to `/Applications/`. No special permissions required (user-owned).

### 2. Config directory — `~/.config/browser-proxy/`

- Created automatically on first run if it doesn't exist
- Permissions: `0755`

### 3. Config file — `~/.config/browser-proxy/config.json`

Created automatically on first run with defaults. Example:

```json
{
  "defaultBrowser": "chrome",
  "rules": [
    {
      "senderName": "Slack",
      "browser": "firefox"
    }
  ]
}
```

Fields:
- `defaultBrowser` — `"chrome"` or `"firefox"`, fallback when no rule matches
- `logFile` — optional, defaults to `~/Library/Logs/browser-proxy/url.log`
- `rules` — array of routing rules, each with:
  - `senderName` (string, optional) — match by sending app's display name (case-insensitive)
  - `senderBundleId` (string, optional) — match by sending app's bundle ID (case-insensitive)
  - `browser` (string) — `"chrome"` or `"firefox"`
  - First matching rule wins; if no rule matches, `defaultBrowser` is used

### 4. Log directory — `~/Library/Logs/browser-proxy/`

- Standard macOS per-user log location (no elevated permissions needed)
- Created automatically when the first URL is handled
- Permissions: `0755`

### 5. Log file — `~/Library/Logs/browser-proxy/url.log`

- One JSON object per line (JSONL format)
- Each entry contains: `timestamp`, `url`, `senderBundleId`, `senderName`, `chosenBrowser`, `wasManualChoice`
- Created automatically, permissions: `0644`

## System Registrations

### LaunchServices Registration

The app must be registered with macOS LaunchServices so the OS knows it can handle URLs:

```bash
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -R -f /Applications/BrowserProxy.app
```

### Set as Default Browser

Uses the `defaultbrowser` CLI tool:

```bash
defaultbrowser browserproxy
```

This sets BrowserProxy as the handler for `http` and `https` URL schemes. The user will see a macOS confirmation dialog.

### Login Items (auto-start on login)

Add to macOS Login Items so it starts automatically after reboot:

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/BrowserProxy.app", hidden:true}'
```

The `hidden:true` flag prevents any window from appearing on login.

## Installation Steps (in order)

1. **Copy app bundle** to `/Applications/BrowserProxy.app`
2. **Register with LaunchServices** (lsregister command above)
3. **Launch the app** — `open /Applications/BrowserProxy.app`
4. **Set as default browser** — `defaultbrowser browserproxy` (triggers macOS confirmation)
5. **Add to Login Items** — osascript command above
6. **Copy default config** — write `config.json` to `~/.config/browser-proxy/` (optional; app creates defaults on first run)

## Uninstallation Steps

1. **Kill the process** — `pkill -x BrowserProxy`
2. **Remove from Login Items** — `osascript -e 'tell application "System Events" to delete login item "BrowserProxy"'`
3. **Unregister from LaunchServices** — `lsregister -u /Applications/BrowserProxy.app`
4. **Delete the app** — `rm -rf /Applications/BrowserProxy.app`
5. **Reset default browser** — user should manually set another browser in System Settings
6. **Optionally remove config and logs**:
   - `rm -rf ~/.config/browser-proxy/`
   - `rm -rf ~/Library/Logs/browser-proxy/`

## Process Lifecycle

- BrowserProxy runs as a persistent background Cocoa app (NSApplication run loop)
- It has no dock icon and no menu bar presence (`LSUIElement = true`)
- It idles with near-zero CPU until macOS sends it a URL event
- After `make install`, the old process must be killed and the app relaunched for code changes to take effect
- Config file changes (`config.json`) take effect immediately — the config is re-read on every URL event
