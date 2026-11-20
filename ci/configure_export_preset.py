#!/usr/bin/env python3
"""Fills signing/version fields of the iOS export preset from environment
variables (set from GitHub Secrets on the macOS runner).

Required env: APPLE_TEAM_ID, APP_BUNDLE_ID, PROFILE_UUID, PROFILE_NAME,
              APP_VERSION, BUILD_NUMBER
"""
import os
import re
import sys

PRESET = os.path.join(os.path.dirname(__file__), "..", "export_presets.cfg")

VALUES = {
    "application/app_store_team_id": os.environ["APPLE_TEAM_ID"],
    "application/bundle_identifier": os.environ["APP_BUNDLE_ID"],
    "application/provisioning_profile_uuid_release": os.environ["PROFILE_UUID"],
    "application/provisioning_profile_specifier_release": os.environ["PROFILE_NAME"],
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
