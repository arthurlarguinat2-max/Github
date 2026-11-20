#!/usr/bin/env bash
# Imports the project then runs the headless simulation tests.
# Fails on test failures AND on any GDScript error printed by the engine.
set -uo pipefail
GODOT_BIN="${GODOT_BIN:?GODOT_BIN must be set}"
cd "$(dirname "$0")/.."

# First import builds the .godot cache (script classes, resources).
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

LOG="$(mktemp)"
"$GODOT_BIN" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}

if grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG" >/dev/null; then
  echo "::error::GDScript errors detected in test output"
  exit 1
fi
exit "$STATUS"
