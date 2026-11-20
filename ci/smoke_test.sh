#!/usr/bin/env bash
# Boots the real game (main scene + autoloads) headless for 120 frames.
# Catches parse/runtime errors in every script reachable from the game.
set -uo pipefail
GODOT_BIN="${GODOT_BIN:?GODOT_BIN must be set}"
cd "$(dirname "$0")/.."
LOG="$(mktemp)"
"$GODOT_BIN" --headless --path . --quit-after 120 2>&1 | tee "$LOG"
if grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG" >/dev/null; then
  echo "::error::Errors while running the main scene"
  exit 1
fi
echo "✓ main scene smoke test"
