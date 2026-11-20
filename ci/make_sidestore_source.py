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
