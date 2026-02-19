#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

APP_NAME="BrowserProxy"
BUNDLE="build/${APP_NAME}.app"
INSTALL_DIR="/Applications"

red()   { printf "\033[1;31m%s\033[0m\n" "$*"; }
green() { printf "\033[1;32m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

bold "BrowserProxy Installer"
echo "─────────────────────────────────"
echo ""

# ── Platform check ──────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    red "Error: BrowserProxy only runs on macOS."
    exit 1
fi

# ── Prerequisite: Go ────────────────────────────────────────────
if ! command -v go &>/dev/null; then
    red "Error: Go is not installed."
    echo "Install it with:  brew install go"
    echo "Or download from: https://go.dev/dl/"
    exit 1
fi

# ── Prerequisite: defaultbrowser ────────────────────────────────
if ! command -v defaultbrowser &>/dev/null; then
    bold "Installing defaultbrowser (needed to set the default browser)..."
    if command -v brew &>/dev/null; then
        brew install defaultbrowser
    else
        red "Error: defaultbrowser is not installed and Homebrew is not available."
        echo "Install Homebrew first: https://brew.sh"
        echo "Then run:  brew install defaultbrowser"
        exit 1
    fi
fi

# ── Build ───────────────────────────────────────────────────────
bold "Building ${APP_NAME}..."
make build
echo ""

# ── Install to /Applications ───────────────────────────────────
bold "Installing to ${INSTALL_DIR}/${APP_NAME}.app..."
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.5
cp -R "${BUNDLE}" "${INSTALL_DIR}/"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"${LSREGISTER}" -R -f "${INSTALL_DIR}/${APP_NAME}.app"
echo ""

# ── Launch ──────────────────────────────────────────────────────
bold "Launching ${APP_NAME}..."
open "${INSTALL_DIR}/${APP_NAME}.app"
sleep 1
echo ""

# ── Set as default browser ──────────────────────────────────────
bold "Setting ${APP_NAME} as your default browser..."
echo "  (macOS will show a confirmation dialog — click 'Use BrowserProxy')"
echo ""
defaultbrowser browserproxy
echo ""

# ── Add to Login Items ──────────────────────────────────────────
bold "Adding ${APP_NAME} to Login Items (auto-start on login)..."
osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"${INSTALL_DIR}/${APP_NAME}.app\", hidden:true}" 2>/dev/null || true
echo ""

# ── Done ────────────────────────────────────────────────────────
green "Installation complete!"
echo ""
echo "  Config file:  ~/.config/browser-proxy/config.json"
echo "  Log file:     ~/Library/Logs/browser-proxy/url.log"
echo ""
echo "  Edit the config to add routing rules — changes take effect immediately."
echo "  Hold Option while clicking a link to manually pick a browser."
echo ""
