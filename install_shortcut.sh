#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PATH="$SCRIPT_DIR"
DESKTOP_SRC="$SCRIPT_DIR/muscle-mem.desktop"

if [[ ! -f "$DESKTOP_SRC" ]]; then
    echo "Error: muscle-mem.desktop not found"
    exit 1
fi

# Install to user applications
APPS_DIR="$HOME/.local/share/applications"
mkdir -p "$APPS_DIR"
DESKTOP_DEST="$APPS_DIR/muscle-mem-agent.desktop"
sed "s|REPO_PATH|$REPO_PATH|g" "$DESKTOP_SRC" > "$DESKTOP_DEST"
chmod +x "$DESKTOP_DEST"
echo "Installed: $DESKTOP_DEST"

# Also copy to Desktop if it exists
if [[ -d "$HOME/Desktop" ]]; then
    cp "$DESKTOP_DEST" "$HOME/Desktop/muscle-mem-agent.desktop"
    chmod +x "$HOME/Desktop/muscle-mem-agent.desktop"
    echo "Installed: $HOME/Desktop/muscle-mem-agent.desktop"
fi

echo "Done. You can now launch HIPPO Agent from the application menu or desktop."
