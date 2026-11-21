#!/usr/bin/env python3
"""Bundles the whole project source into 3 Markdown files that can be given
to ChatGPT (or any AI / developer) in one go. Output: POUR_CHATGPT/CODE_*.md
Run from the repository root:  python3 ci/make_chatgpt_bundle.py
"""
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "POUR_CHATGPT")

GROUPS = [
    ("CODE_1_SIMULATION_ET_DONNEES.md",
     "Règles du jeu (simulation pure, testable), données JSON, textes FR/EN et tests.",
     ["scripts/simulation/", "scripts/core/", "data/", "tests/", "project.godot", "VERSION"]),
    ("CODE_2_RENDU_ET_INTERFACE.md",
     "Rendu 3D (planète, bâtiments, vie), interface (HUD, menus, design) et scène principale.",
     ["scripts/render/", "scripts/ui/", "scripts/main.gd", "scripts/platform/", "scripts/dev/", "scenes/"]),
    ("CODE_3_BUILD_ET_CI.md",
     "Fabrication de l'app iPhone : GitHub Actions, scripts CI, export Godot, fastlane.",
     [".github/workflows/", "ci/", "fastlane/", "export_presets.cfg", "Gemfile"]),
]
LANG = {".gd": "gdscript", ".json": "json", ".py": "python", ".sh": "bash", ".yml": "yaml",
        ".cfg": "ini", ".godot": "ini", ".tscn": "ini", "Fastfile": "ruby", "Appfile": "ruby", "Gemfile": "ruby"}


def tracked_files():
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [f for f in out.splitlines() if f]


def lang_of(path):
    base = os.path.basename(path)
    if base in LANG:
        return LANG[base]
    return LANG.get(os.path.splitext(path)[1], "")


def main():
    files = tracked_files()
    version = open(os.path.join(ROOT, "VERSION")).read().strip()
    for name, description, prefixes in GROUPS:
        chosen = [f for f in files if any(f == p or f.startswith(p) for p in prefixes)
                  and not f.endswith((".png", ".svg", ".gdignore"))]
        parts = [f"# Mini Planète — {name[:-3]}\n",
                 f"{description}\n",
                 f"Version du jeu : {version}.x — {len(chosen)} fichiers. "
                 "Chaque fichier commence par une ligne « ### FICHIER : chemin ». "
                 "Pour modifier un fichier, renvoie-le EN ENTIER avec son chemin.\n"]
        parts.append("## Sommaire\n" + "\n".join(f"- {f}" for f in chosen) + "\n")
        for f in chosen:
            with open(os.path.join(ROOT, f), encoding="utf-8") as fh:
                content = fh.read()
            parts.append(f"\n### FICHIER : {f}\n\n```{lang_of(f)}\n{content.rstrip()}\n```\n")
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as fh:
            fh.write("\n".join(parts))
        print(name, len(chosen), "fichiers")


if __name__ == "__main__":
    main()
