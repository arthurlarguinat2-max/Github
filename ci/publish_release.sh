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
