# BrowserProxy

A lightweight macOS app that acts as your default browser and routes URLs to **Chrome** or **Firefox** based on configurable rules. For example, open all links from Slack in Firefox while everything else goes to Chrome.

BrowserProxy runs as a background process with no dock icon and near-zero resource usage.

## Features

- Route URLs to different browsers based on which app sent the link
- Match by app name or bundle ID
- Hold **Option** while clicking a link to manually pick a browser
- JSON config — edit and changes apply instantly (no restart needed)
- Logs every URL event for debugging

## Requirements

- macOS 13+ (tested on macOS 15 Sequoia)
- [Go](https://go.dev/dl/) 1.21+ (for building from source)
- [Homebrew](https://brew.sh) (to install the `defaultbrowser` helper)

## Install

```bash
git clone https://github.com/david-erel/browser-proxy.git
cd browser-proxy
./scripts/install.sh
```

The installer will:

1. Install the `defaultbrowser` helper via Homebrew (if needed)
2. Build the app
3. Copy it to `/Applications`
4. Launch it
5. Set it as your default browser (macOS will ask you to confirm)
6. Add it to Login Items so it starts on boot

That's it. You're done.

## Configuration

Edit `~/.config/browser-proxy/config.json`:

```json
{
  "defaultBrowser": "chrome",
  "rules": [
    {
      "senderName": "Slack",
      "browser": "firefox"
    },
    {
      "senderBundleId": "com.tinyspeck.slackmacgap",
      "browser": "firefox"
    }
  ]
}
```

| Field            | Description                                          |
|------------------|------------------------------------------------------|
| `defaultBrowser` | `"chrome"` or `"firefox"` — used when no rule matches |
| `rules`          | Array of routing rules (first match wins)            |
| `rules[].senderName`     | Match by sending app's display name (case-insensitive) |
| `rules[].senderBundleId` | Match by sending app's bundle ID (case-insensitive)    |
| `rules[].browser`        | `"chrome"` or `"firefox"`                              |
| `logFile`        | Optional — defaults to `~/Library/Logs/browser-proxy/url.log` |

Changes take effect immediately, no restart required.

## Manual Browser Selection

Hold the **Option** key while clicking any link to get a dialog letting you choose Chrome or Firefox for that specific URL.

## Logs

Every URL event is logged as JSONL to `~/Library/Logs/browser-proxy/url.log`:

```json
{"timestamp":"2026-02-18T10:30:00Z","url":"https://example.com","senderBundleId":"com.tinyspeck.slackmacgap","senderName":"Slack","chosenBrowser":"firefox","wasManualChoice":false}
```

## Uninstall

```bash
./scripts/uninstall.sh
```

This stops the app, removes it from Login Items and `/Applications`, and optionally cleans up config and log files. Afterwards, set another browser as your default in **System Settings > Desktop & Dock > Default web browser**.

## Building Manually

If you prefer not to use the installer:

```bash
make build        # Build the .app bundle
make install      # Copy to /Applications and register
make set-default  # Set as default browser
make login-item   # Auto-start on login
make restart      # Rebuild, install, and relaunch
make clean        # Remove build artifacts
make uninstall    # Remove from /Applications
```

## How It Works

BrowserProxy registers itself as a macOS URL handler for `http` and `https` schemes. When any app opens a URL, macOS routes it to BrowserProxy, which:

1. Reads the config file
2. Identifies the sending app
3. Matches against the rules (first match wins, falls back to `defaultBrowser`)
4. Opens the URL in the chosen browser

The app is built with Go and Objective-C (Cocoa) to integrate with macOS native URL handling and LaunchServices.

## License

MIT
