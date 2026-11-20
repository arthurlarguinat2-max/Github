#!/usr/bin/env bash
# Builds an UNSIGNED .ipa (macOS runner). No Apple account or secret needed:
# the player's Mac signs it at install time (Sideloadly + free Apple ID).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# VERSION holds "major.minor"; the patch number is the build number, so every
# build has a higher version and SideStore offers it as an update.
export BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
export APP_VERSION="$(tr -d '[:space:]' < VERSION).${BUILD_NUMBER}"
ci/export_ios.sh

XCODEPROJ="$(cat build/ios/xcodeproj_path.txt)"
SCHEME="$(basename "$XCODEPROJ" .xcodeproj)"

xcodebuild \
  -project "$XCODEPROJ" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination "generic/platform=iOS" \
  -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" PROVISIONING_PROFILE_SPECIFIER="" \
  build | tail -n 40

APP="$(find build/dd/Build/Products -maxdepth 2 -name '*.app' -type d | head -n 1)"
if [[ -z "$APP" ]]; then
  echo "::error::No .app produced"; exit 1
fi

# An .ipa is simply a zip containing Payload/<App>.app
rm -rf build/ipa && mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
(cd build/ipa && zip -qry MiniPlanete.ipa Payload && rm -rf Payload)
echo "$APP_VERSION" > build/ipa/version.txt
ls -la build/ipa
