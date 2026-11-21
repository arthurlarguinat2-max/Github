# Mini Planète 🌍

Jeu de gestion calme et créatif pour iPhone : fais tourner une petite planète
du bout du doigt et guide sa civilisation de l'âge de pierre jusqu'au futur.

- Moteur : **Godot 4** (GDScript, rendu *Mobile*), application **iOS native**.
- 100 % hors ligne, sauvegarde locale, sans publicité ni compte.
- Build iOS **sans ordinateur** (tout depuis un iPhone) : GitHub Actions (macOS) + fastlane → TestFlight privé.
  - **Gratuit, mises à jour depuis l'iPhone** (SideStore, Mac une seule fois) : **[INSTALL_SIDESTORE.md](INSTALL_SIDESTORE.md)**.
  - **Gratuit avec un Mac à chaque fois** (Sideloadly) : [INSTALL_MAC.md](INSTALL_MAC.md).
  - **TestFlight** (compte Apple payant, iPhone seul) : **[BUILD.md](BUILD.md)**.

## Structure

```
scenes/            Scènes Godot (main.tscn : point d'entrée)
scripts/
  simulation/      Logique pure du jeu (testable, sans Node ni rendu)
  core/            Autoloads : GameState (boucle à pas fixe, sauvegarde), Loc (langues)
  render/          Rendu 3D (planète, nuages…)
  ui/              Interface (HUD, safe area)
  platform/        Spécificités iPhone (haptique…)
data/              Données modifiables sans toucher au code (JSON)
  locale/          Textes FR (défaut) / EN
assets/            Icônes, modèles, sons (CC0 uniquement, crédités dans CREDITS.md)
tests/             Tests headless (tests/unit/test_*.gd)
ci/                Scripts CI (installation Godot, tests, export iOS)
fastlane/          Signature + build Xcode + envoi TestFlight
```

## Principes

- **Simulation séparée du rendu** : `scripts/simulation/` n'utilise ni nœuds ni
  rendu ; `GameState` la fait avancer par *ticks* fixes (10/s, ×0 ×1 ×2 ×4),
  indépendamment du framerate.
- **Sauvegarde** JSON versionnée dans `user://savegame.json`, écriture atomique,
  copie `.bak`, migrations (`scripts/core/save_manager.gd`). Une sauvegarde
  venant d'une version plus récente n'est jamais écrasée.
- **Progression hors ligne** plafonnée (`data/game_config.json`).

## Développer

1. Installe Godot 4.7 (version « standard », pas .NET) et ouvre `project.godot`.
2. F5 pour lancer. À la souris : clic‑glisser pour faire tourner la planète.
3. Tests :
   ```bash
   godot --headless --path . --import
   godot --headless --path . -s res://tests/run_tests.gd
   ```

## Feuille de route

| Phase | Contenu | État |
|---|---|---|
| 0 | Fondations, CI, TestFlight, « Hello Planète » 3D | ✅ |
| 1 | Planète hexagonale (Goldberg), caméra tactile, sélection, jour/nuit | ✅ |
| 2 | Âge de pierre : ressources, bâtiments, population, sauvegarde | ✅ |
| 3 | Économie : chaînes de production, besoins, bonheur | |
| 4 | Science, arbre technologique, Antiquité, Médiéval | |
| 5 | Environnement : pollution, climat, eau, événements | |
| 6 | Industriel, Moderne, Futuriste, énergie | |
| 7 | Finition : audio, haptique, tutoriel, succès, menus | |
| 8 | Publication App Store | |
