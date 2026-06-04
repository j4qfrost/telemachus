#!/usr/bin/env bash
# Install a Telemachus app-menu entry for the current user (Linux).
#
#   ./install-desktop.sh            # install
#   ./install-desktop.sh --uninstall
#
# Drops a .desktop launcher into ~/.local/share/applications and an icon into
# the hicolor theme, both pointing at this repo's start-linux.sh. No root needed.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps"
DESKTOP="$APPS_DIR/telemachus.desktop"
ICON="$ICON_DIR/telemachus.png"

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$DESKTOP" "$ICON"
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
  echo "Removed Telemachus desktop entry."
  exit 0
fi

mkdir -p "$APPS_DIR" "$ICON_DIR"

# Icon: convert the shipped docs/odysseus.jpg to PNG if a converter exists,
# else fall back to copying the jpg under the .png name (most icon loaders sniff
# the content, not the extension). Non-fatal either way.
SRC_IMG="$REPO_DIR/docs/odysseus.jpg"
if [ -f "$SRC_IMG" ]; then
  if command -v convert >/dev/null 2>&1; then
    convert "$SRC_IMG" -resize 512x512^ -gravity center -extent 512x512 "$ICON" 2>/dev/null || cp "$SRC_IMG" "$ICON"
  else
    cp "$SRC_IMG" "$ICON"
  fi
fi

# Render the .desktop with an absolute Exec and Icon path.
sed -e "s#^Exec=.*#Exec=$REPO_DIR/start-linux.sh#" \
    -e "s#^Icon=.*#Icon=$ICON#" \
    "$REPO_DIR/telemachus.desktop" >"$DESKTOP"
chmod +x "$REPO_DIR/start-linux.sh"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true

echo "Installed Telemachus launcher:"
echo "  $DESKTOP"
echo "Find 'Telemachus' in your app menu, or run: $REPO_DIR/start-linux.sh"
