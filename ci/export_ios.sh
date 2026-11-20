#!/usr/bin/env bash
# Exports the Godot project as an Xcode project (macOS runner only).
# Called by fastlane (lane ios beta) after signing assets are installed.
set -euo pipefail
GODOT_BIN="${GODOT_BIN:?GODOT_BIN must be set}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

python3 ci/configure_export_preset.py
rm -rf build/ios && mkdir -p build/ios

"$GODOT_BIN" --headless --path . --import || true
"$GODOT_BIN" --headless --path . --export-release "iOS" build/ios/MiniPlanete.ipa

XCODEPROJ="$(find build/ios -maxdepth 1 -name '*.xcodeproj' | head -n 1)"
if [[ -z "$XCODEPROJ" ]]; then
  echo "::error::Godot did not produce an Xcode project"; ls -la build/ios; exit 1
fi

# Belt and braces: declare "no custom encryption" so TestFlight does not ask.
PLIST="$(find build/ios -maxdepth 2 -name '*-Info.plist' | head -n 1)"
if [[ -n "$PLIST" ]]; then
  /usr/libexec/PlistBuddy -c "Set :ITSAppUsesNonExemptEncryption false" "$PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"
fi
echo "$ROOT/$XCODEPROJ" > build/ios/xcodeproj_path.txt
echo "Xcode project: $XCODEPROJ"
