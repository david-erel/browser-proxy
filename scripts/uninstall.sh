#!/usr/bin/env bash
set -euo pipefail

APP_NAME="BrowserProxy"
INSTALL_DIR="/Applications"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

red()   { printf "\033[1;31m%s\033[0m\n" "$*"; }
green() { printf "\033[1;32m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

bold "BrowserProxy Uninstaller"
echo "─────────────────────────────────"
echo ""

# ── Stop ────────────────────────────────────────────────────────
bold "Stopping ${APP_NAME}..."
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.5

# ── Remove Login Item ───────────────────────────────────────────
bold "Removing from Login Items..."
osascript -e "tell application \"System Events\" to delete login item \"${APP_NAME}\"" 2>/dev/null || true

# ── Unregister from LaunchServices ──────────────────────────────
bold "Unregistering from LaunchServices..."
"${LSREGISTER}" -u "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

# ── Delete app ──────────────────────────────────────────────────
bold "Removing ${INSTALL_DIR}/${APP_NAME}.app..."
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"

# ── Optional cleanup ────────────────────────────────────────────
echo ""
read -rp "Remove config and log files too? [y/N] " answer
if [[ "${answer}" =~ ^[Yy]$ ]]; then
    rm -rf ~/.config/browser-proxy/
    rm -rf ~/Library/Logs/browser-proxy/
    green "Config and logs removed."
fi

echo ""
green "BrowserProxy has been uninstalled."
echo ""
echo "  Set another browser as your default in:"
echo "  System Settings > Desktop & Dock > Default web browser"
echo ""
