#!/usr/bin/env bash
# Downloads the Godot editor (+ optionally export templates) for the CI runner.
# Usage: ci/install_godot.sh <linux|macos> [--templates]
# Prints nothing special; exports GODOT_BIN through $GITHUB_ENV when available.
set -euo pipefail

PLATFORM="${1:?linux|macos}"
WITH_TEMPLATES="${2:-}"
VERSION="${GODOT_VERSION:?GODOT_VERSION must be set}"
RELEASE="${GODOT_RELEASE:-stable}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}-${RELEASE}"
DEST="${GODOT_DIR:-$HOME/godot}"
mkdir -p "$DEST"
cd "$DEST"

if [[ "$PLATFORM" == "linux" ]]; then
  ZIP="Godot_v${VERSION}-${RELEASE}_linux.x86_64.zip"
  BIN="$DEST/Godot_v${VERSION}-${RELEASE}_linux.x86_64"
  TEMPLATE_ROOT="$HOME/.local/share/godot/export_templates"
else
  ZIP="Godot_v${VERSION}-${RELEASE}_macos.universal.zip"
  BIN="$DEST/Godot.app/Contents/MacOS/Godot"
  TEMPLATE_ROOT="$HOME/Library/Application Support/Godot/export_templates"
fi

if [[ ! -x "$BIN" ]]; then
  curl -fsSL --retry 4 -o "$ZIP" "$BASE/$ZIP"
  unzip -q -o "$ZIP"
  rm -f "$ZIP"
fi
chmod +x "$BIN"

if [[ "$WITH_TEMPLATES" == "--templates" ]]; then
  TPL_DIR="$TEMPLATE_ROOT/${VERSION}.${RELEASE}"
  if [[ ! -f "$TPL_DIR/version.txt" ]]; then
    TPZ="Godot_v${VERSION}-${RELEASE}_export_templates.tpz"
    curl -fsSL --retry 4 -o "$TPZ" "$BASE/$TPZ"
    mkdir -p "$TPL_DIR"
    # Only the iOS template and version file are needed: keeps the cache small.
    unzip -q -o "$TPZ" "templates/version.txt" "templates/ios*" -d tpl_tmp
    mv tpl_tmp/templates/* "$TPL_DIR/"
    rm -rf tpl_tmp "$TPZ"
  fi
  ls -la "$TPL_DIR"
fi

"$BIN" --version
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "GODOT_BIN=$BIN" >> "$GITHUB_ENV"
fi
