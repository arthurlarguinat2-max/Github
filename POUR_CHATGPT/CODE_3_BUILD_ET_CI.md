# Mini Planète — CODE_3_BUILD_ET_CI

Fabrication de l'app iPhone : GitHub Actions, scripts CI, export Godot, fastlane.

Version du jeu : 0.6.x — 16 fichiers. Chaque fichier commence par une ligne « ### FICHIER : chemin ». Pour modifier un fichier, renvoie-le EN ENTIER avec son chemin.

## Sommaire
- .github/workflows/ios-testflight.yml
- .github/workflows/ios-unsigned.yml
- .github/workflows/screenshots.yml
- .github/workflows/tests.yml
- Gemfile
- ci/build_unsigned_ipa.sh
- ci/configure_export_preset.py
- ci/export_ios.sh
- ci/install_godot.sh
- ci/make_sidestore_source.py
- ci/publish_release.sh
- ci/run_tests.sh
- ci/smoke_test.sh
- export_presets.cfg
- fastlane/Appfile
- fastlane/Fastfile


### FICHIER : .github/workflows/ios-testflight.yml

```yaml
# Builds the iOS app on a macOS runner and uploads it to TestFlight.
# Triggered by a tag "v*" (e.g. v0.1.0) or manually from the Actions tab.
# All required secrets are documented in BUILD.md.
name: iOS → TestFlight

on:
  push:
    tags: ["v*"]
  workflow_dispatch:

env:
  GODOT_VERSION: "4.7.2"

# Needed so fastlane match can store the encrypted signing files
# on the "match-signing" branch of this repository.
permissions:
  contents: write

concurrency:
  group: ios-testflight
  cancel-in-progress: false

jobs:
  testflight:
    runs-on: macos-15
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v5

      - name: Select latest stable Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Cache Godot + iOS templates
        uses: actions/cache@v5
        with:
          path: |
            ~/godot
            ~/Library/Application Support/Godot/export_templates
          key: godot-macos-${{ env.GODOT_VERSION }}

      - name: Install Godot + export templates
        run: ci/install_godot.sh macos --templates

      - name: Set up Ruby + fastlane
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true

      - name: Git credentials for fastlane match
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          AUTH="$(printf 'x-access-token:%s' "$GH_TOKEN" | base64 | tr -d '\n')"
          echo "::add-mask::$AUTH"
          echo "MATCH_GIT_BASIC_AUTHORIZATION=$AUTH" >> "$GITHUB_ENV"

      - name: Build and upload to TestFlight
        env:
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          APP_BUNDLE_ID: ${{ secrets.APP_BUNDLE_ID }}
          ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY_P8: ${{ secrets.ASC_KEY_P8 }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
        run: bundle exec fastlane ios beta

      - name: Keep the IPA and logs
        if: always()
        uses: actions/upload-artifact@v5
        with:
          name: ios-build-${{ github.run_number }}
          path: |
            build/ipa/*.ipa
            ~/Library/Logs/gym/*.log
          if-no-files-found: ignore
          retention-days: 14
```


### FICHIER : .github/workflows/ios-unsigned.yml

```yaml
# Free iPhone builds (no Apple Developer account):
#   tests → unsigned IPA → GitHub Release + SideStore source.
# Runs on every push of game code, or manually from the Actions tab.
# The iPhone gets the update from SideStore. Guide: INSTALL_SIDESTORE.md
name: iOS – version gratuite (SideStore)

on:
  workflow_dispatch:
  push:
    branches: [main, "claude/**"]
    paths-ignore: ["**.md", "docs/**"]

env:
  GODOT_VERSION: "4.7.2"

permissions:
  contents: write  # create releases

concurrency:
  group: ios-free
  cancel-in-progress: true

jobs:
  tests:
    uses: ./.github/workflows/tests.yml

  unsigned-ipa:
    needs: tests
    runs-on: macos-15
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v5

      - name: Select latest stable Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Cache Godot + iOS templates
        uses: actions/cache@v5
        with:
          path: |
            ~/godot
            ~/Library/Application Support/Godot/export_templates
          key: godot-macos-${{ env.GODOT_VERSION }}

      - name: Install Godot + export templates
        run: ci/install_godot.sh macos --templates

      - name: Build unsigned IPA
        run: ci/build_unsigned_ipa.sh

      - name: Publish release + SideStore source
        env:
          GH_TOKEN: ${{ github.token }}
        run: ci/publish_release.sh

      - name: Upload IPA (backup)
        uses: actions/upload-artifact@v5
        with:
          name: MiniPlanete-ipa
          path: build/ipa/MiniPlanete.ipa
          if-no-files-found: error
          retention-days: 14
```


### FICHIER : .github/workflows/screenshots.yml

```yaml
# Renders the real game in a virtual screen and captures the main screens,
# so the visual design can be checked without an iPhone. The images are
# published on the "screenshots" pre-release (never marked as latest).
name: Captures d'écran

on:
  workflow_dispatch:
  push:
    branches: [main, "claude/**"]
    paths: ["scripts/**", "data/**", "assets/**", "scenes/**", "project.godot"]

env:
  GODOT_VERSION: "4.7.2"

permissions:
  contents: write

concurrency:
  group: screenshots
  cancel-in-progress: true

jobs:
  screenshots:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v5

      - name: Cache Godot
        uses: actions/cache@v5
        with:
          path: ~/godot
          key: godot-linux-${{ env.GODOT_VERSION }}

      - name: Install Godot
        run: ci/install_godot.sh linux

      - name: Virtual screen + OpenGL
        run: sudo apt-get update -q && sudo apt-get install -y -q xvfb libgl1 libgl1-mesa-dri libglx-mesa0

      - name: Capture screens
        run: |
          "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true
          mkdir -p build/shots
          xvfb-run -a -s "-screen 0 1280x1024x24" \
            "$GODOT_BIN" --rendering-method gl_compatibility --rendering-driver opengl3 \
            --resolution 390x844 --path . -- --screenshot-dir="$PWD/build/shots" 2>&1 | tail -n 30
          ls -la build/shots

      - name: Publish screenshots
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release view screenshots >/dev/null 2>&1 || \
            gh release create screenshots --prerelease --latest=false \
              --title "Captures d'écran (automatiques)" --notes "Images générées par la CI."
          gh release upload screenshots build/shots/*.png --clobber

      - uses: actions/upload-artifact@v5
        with:
          name: screenshots
          path: build/shots/*.png
          retention-days: 14
```


### FICHIER : .github/workflows/tests.yml

```yaml
# Runs on every push: headless simulation tests + main scene smoke test (Linux).
name: Tests

on:
  push:
  pull_request:
  workflow_dispatch:
  workflow_call:  # reused by the iOS free-build workflow before publishing

env:
  GODOT_VERSION: "4.7.2"

jobs:
  tests:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v5

      - name: Cache Godot
        uses: actions/cache@v5
        with:
          path: ~/godot
          key: godot-linux-${{ env.GODOT_VERSION }}

      - name: Install Godot
        run: ci/install_godot.sh linux

      - name: Unit tests (simulation, save, data)
        run: ci/run_tests.sh

      - name: Smoke test (main scene)
        run: ci/smoke_test.sh
```


### FICHIER : Gemfile

```ruby
source "https://rubygems.org"

gem "fastlane", "~> 2.228"
```


### FICHIER : ci/build_unsigned_ipa.sh

```bash
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
# Show the same version inside the game as in AltStore/SideStore.
sed -i '' "s/^config\/version=.*/config\/version=\"${APP_VERSION}\"/" project.godot
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
```


### FICHIER : ci/configure_export_preset.py

```python
#!/usr/bin/env python3
"""Fills signing/version fields of the iOS export preset from environment
variables (set from GitHub Secrets on the macOS runner).

Env: APPLE_TEAM_ID, APP_BUNDLE_ID, PROFILE_UUID, PROFILE_NAME,
     APP_VERSION, BUILD_NUMBER.
For the unsigned build (free install with Sideloadly), signing values are
optional and placeholders are used: the Mac re-signs the app on install.
"""
import os
import re
import sys

PRESET = os.path.join(os.path.dirname(__file__), "..", "export_presets.cfg")

VALUES = {
    "application/app_store_team_id": os.environ.get("APPLE_TEAM_ID") or "ABCDE12345",
    "application/bundle_identifier": os.environ.get("APP_BUNDLE_ID") or "com.miniplanete.game",
    "application/provisioning_profile_uuid_release": os.environ.get("PROFILE_UUID", ""),
    "application/provisioning_profile_specifier_release": os.environ.get("PROFILE_NAME", ""),
    "application/short_version": os.environ["APP_VERSION"],
    "application/version": os.environ["BUILD_NUMBER"],
}


def main() -> int:
    with open(PRESET, encoding="utf-8") as f:
        text = f.read()
    for key, value in VALUES.items():
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        line = f'{key}="{escaped}"'
        pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
        if pattern.search(text):
            text = pattern.sub(lambda _m: line, text)
        else:
            text = text.replace("[preset.0.options]\n", f"[preset.0.options]\n\n{line}\n", 1)
    with open(PRESET, "w", encoding="utf-8") as f:
        f.write(text)
    print("Export preset configured for", VALUES["application/bundle_identifier"],
          "version", VALUES["application/short_version"], "build", VALUES["application/version"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
```


### FICHIER : ci/export_ios.sh

```bash
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
```


### FICHIER : ci/install_godot.sh

```bash
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
```


### FICHIER : ci/make_sidestore_source.py

```python
#!/usr/bin/env python3
"""Writes the SideStore / AltStore "source" JSON describing the latest build.

SideStore reads it from a stable URL (latest GitHub release asset) and shows an
"Update" button on the iPhone whenever a newer version is published.
Env: GITHUB_REPOSITORY, GITHUB_SHA, RELEASE_TAG, APP_VERSION, BUILD_NUMBER,
     IPA_PATH, CHANGELOG, APP_BUNDLE_ID (optional)
"""
import datetime
import json
import os

repo = os.environ["GITHUB_REPOSITORY"]
sha = os.environ["GITHUB_SHA"]
tag = os.environ["RELEASE_TAG"]
ipa = os.environ["IPA_PATH"]
icon = f"https://raw.githubusercontent.com/{repo}/{sha}/assets/icons/app_icon_1024.png"
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

source = {
    "name": "Mini Planète",
    "identifier": "io.github.miniplanete.source",
    "subtitle": "Versions de test de Mini Planète",
    "iconURL": icon,
    "tintColor": "#3F86C6",
    "apps": [
        {
            "name": "Mini Planète",
            "bundleIdentifier": os.environ.get("APP_BUNDLE_ID") or "com.miniplanete.game",
            "developerName": "Mini Planète",
            "subtitle": "Fais grandir une civilisation sur ta petite planète.",
            "localizedDescription": (
                "Jeu de gestion calme et créatif : fais tourner une petite planète "
                "et guide sa civilisation de l'âge de pierre jusqu'au futur."
            ),
            "iconURL": icon,
            "tintColor": "#3F86C6",
            "category": "games",
            "versions": [
                {
                    "version": os.environ["APP_VERSION"],
                    "buildVersion": os.environ["BUILD_NUMBER"],
                    "date": now,
                    "localizedDescription": os.environ.get("CHANGELOG", ""),
                    "downloadURL": f"https://github.com/{repo}/releases/download/{tag}/MiniPlanete.ipa",
                    "size": os.path.getsize(ipa),
                    "minOSVersion": "15.0",
                }
            ],
            "appPermissions": {"entitlements": [], "privacy": {}},
        }
    ],
    "news": [],
}
print(json.dumps(source, ensure_ascii=False, indent=2))
```


### FICHIER : ci/publish_release.sh

```bash
#!/usr/bin/env bash
# Publishes the unsigned IPA as a GitHub Release + the SideStore source JSON.
# Stable source URL for the iPhone:
#   https://github.com/<owner>/<repo>/releases/latest/download/source.json
set -euo pipefail
cd "$(dirname "$0")/.."

export APP_VERSION="$(cat build/ipa/version.txt)"
export BUILD_NUMBER="${GITHUB_RUN_NUMBER:?}"
export RELEASE_TAG="build-${BUILD_NUMBER}"
export IPA_PATH="build/ipa/MiniPlanete.ipa"
export CHANGELOG="$(git log -1 --pretty=%s)"

python3 ci/make_sidestore_source.py > build/ipa/source.json

gh release create "$RELEASE_TAG" "$IPA_PATH" build/ipa/source.json \
  --title "Mini Planète ${APP_VERSION}" \
  --notes "${CHANGELOG}" \
  --target "$GITHUB_SHA" \
  --latest

# Keep only the 5 most recent builds (each IPA is ~25 MB).
gh release list --limit 100 --json tagName --jq '.[].tagName' \
  | grep '^build-' | sort -t- -k2 -n -r | tail -n +6 \
  | xargs -r -n1 gh release delete --cleanup-tag --yes

echo "Published ${RELEASE_TAG} (version ${APP_VERSION})"
echo "SideStore source: https://github.com/${GITHUB_REPOSITORY}/releases/latest/download/source.json"
```


### FICHIER : ci/run_tests.sh

```bash
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
```


### FICHIER : ci/smoke_test.sh

```bash
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
```


### FICHIER : export_presets.cfg

```ini
; iOS export preset. Signing values are left empty on purpose:
; ci/configure_export_preset.py fills them on the macOS runner from GitHub
; Secrets, so no Apple identifier needs to be committed.

[preset.0]

name="iOS"
platform="iOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="*.json"
exclude_filter="tests/*, ci/*, fastlane/*, build/*"
export_path="build/ios/MiniPlanete.ipa"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
architectures/arm64=true
application/app_store_team_id=""
application/export_method_debug=1
application/code_sign_identity_debug="Apple Development"
application/code_sign_identity_release="Apple Distribution"
application/provisioning_profile_uuid_debug=""
application/provisioning_profile_uuid_release=""
application/provisioning_profile_specifier_release=""
application/export_method_release=0
application/targeted_device_family=0
application/bundle_identifier="com.example.miniplanete"
application/signature="MPLN"
application/short_version="0.1.0"
application/version="1"
application/min_ios_version="15.0"
application/additional_plist_content="<key>ITSAppUsesNonExemptEncryption</key><false/>"
application/icon_interpolation=4
application/export_project_only=true
application/delete_old_export_files_unconditionally=true
capabilities/access_wifi=false
capabilities/performance_gaming_tier=false
capabilities/performance_a12=false
user_data/accessible_from_files_app=false
user_data/accessible_from_itunes_sharing=false
privacy/camera_usage_description=""
privacy/microphone_usage_description=""
privacy/photolibrary_usage_description=""
privacy/collected_data/name/collected=false
icons/icon_1024x1024="res://assets/icons/app_icon_1024.png"
icons/app_store_1024x1024="res://assets/icons/app_icon_1024.png"
storyboard/image_scale_mode=0
storyboard/use_custom_bg_color=true
storyboard/custom_bg_color=Color(1, 0.965, 0.914, 1)
```


### FICHIER : fastlane/Appfile

```ruby
# Values come from GitHub Secrets (see BUILD.md); nothing personal is committed.
app_identifier(ENV["APP_BUNDLE_ID"])
team_id(ENV["APPLE_TEAM_ID"])
```


### FICHIER : fastlane/Fastfile

```ruby
# Mini Planète — iOS lane, run on a GitHub macOS runner.
#   bundle exec fastlane ios beta
#
# Designed for a player who owns ONLY an iPhone: no certificate is made by hand.
# fastlane "match" creates the Apple Distribution certificate and the App Store
# profile through the App Store Connect API the first time, stores them
# ENCRYPTED (MATCH_PASSWORD) on the "match-signing" branch of this repository,
# and reuses them on every following build.
#
# Steps: API key → Bundle ID → build number → signing (match) → Godot export
#        → Xcode build → TestFlight (private, internal testers only).

default_platform(:ios)

ROOT = File.expand_path("..", __dir__)

def require_env(name)
  value = ENV[name].to_s.strip
  UI.user_error!("Missing secret #{name} (see BUILD.md)") if value.empty?
  value
end

# The .p8 key may be pasted as plain text (easiest from an iPhone) or base64.
def api_key_content
  raw = require_env("ASC_KEY_P8")
  return raw if raw.include?("BEGIN PRIVATE KEY")
  decoded = Base64.decode64(raw)
  UI.user_error!("ASC_KEY_P8 is not a valid .p8 key (see BUILD.md)") unless decoded.include?("BEGIN PRIVATE KEY")
  decoded
end

platform :ios do
  desc "Export with Godot, build, sign and upload to TestFlight"
  lane :beta do
    team_id = require_env("APPLE_TEAM_ID")
    bundle_id = require_env("APP_BUNDLE_ID")
    require_env("MATCH_PASSWORD")

    # 1. App Store Connect API key (no Apple ID password / 2FA needed).
    api_key = app_store_connect_api_key(
      key_id: require_env("ASC_KEY_ID"),
      issuer_id: require_env("ASC_ISSUER_ID"),
      key_content: api_key_content,
      in_house: false
    )

    # 2. Register the Bundle ID if it does not exist yet.
    if Spaceship::ConnectAPI::BundleId.find(bundle_id).nil?
      UI.message("Registering Bundle ID #{bundle_id}")
      Spaceship::ConnectAPI::BundleId.create(
        name: "Mini Planete", platform: "IOS", identifier: bundle_id
      )
    end

    # 3. Build number: always above the latest TestFlight build.
    latest = latest_testflight_build_number(
      api_key: api_key, app_identifier: bundle_id, initial_build_number: 0
    ).to_i
    build_number = [latest + 1, ENV["GITHUB_RUN_NUMBER"].to_i].max
    app_version = File.read(File.join(ROOT, "VERSION")).strip
    UI.message("Version #{app_version} (build #{build_number})")

    # 4. Signing: certificate + profile created once, then reused (encrypted).
    setup_ci(force: true)
    match(
      type: "appstore",
      app_identifier: bundle_id,
      team_id: team_id,
      api_key: api_key,
      storage_mode: "git",
      git_url: "https://github.com/#{require_env('GITHUB_REPOSITORY')}.git",
      git_branch: "match-signing",
      git_basic_authorization: require_env("MATCH_GIT_BASIC_AUTHORIZATION"),
      readonly: false,
      keychain_name: "fastlane_tmp_keychain",
      keychain_password: ""
    )
    profile_uuid = ENV["sigh_#{bundle_id}_appstore"]
    profile_name = ENV["sigh_#{bundle_id}_appstore_profile-name"]
    UI.user_error!("match did not provide a provisioning profile") if profile_uuid.to_s.empty?
    UI.message("Provisioning profile: #{profile_name} (#{profile_uuid})")

    # 5. Godot → Xcode project.
    sh(
      {
        "PROFILE_UUID" => profile_uuid,
        "PROFILE_NAME" => profile_name,
        "APP_VERSION" => app_version,
        "BUILD_NUMBER" => build_number.to_s
      },
      File.join(ROOT, "ci", "export_ios.sh")
    )
    xcodeproj = File.read(File.join(ROOT, "build", "ios", "xcodeproj_path.txt")).strip
    scheme = File.basename(xcodeproj, ".xcodeproj")

    # 6. Force manual signing with the match certificate and profile.
    update_code_signing_settings(
      path: xcodeproj,
      use_automatic_signing: false,
      team_id: team_id,
      code_sign_identity: "Apple Distribution",
      profile_name: profile_name,
      profile_uuid: profile_uuid,
      bundle_identifier: bundle_id,
      build_configurations: ["Release"]
    )

    # 7. Archive + IPA.
    ipa = build_app(
      project: xcodeproj,
      scheme: scheme,
      configuration: "Release",
      export_method: "app-store",
      output_directory: File.join(ROOT, "build", "ipa"),
      output_name: "MiniPlanete.ipa",
      clean: true,
      export_options: {
        provisioningProfiles: { bundle_id => profile_name },
        signingStyle: "manual",
        teamID: team_id
      }
    )

    # 8. TestFlight. Internal testers only: nothing is published or sold.
    upload_to_testflight(
      api_key: api_key,
      ipa: ipa,
      skip_waiting_for_build_processing: true
    )
  end
end
```
