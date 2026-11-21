# Mini Planète — description technique complète

## 1. Le jeu en bref
Petite planète 3D que l'on fait tourner au doigt (portrait, iPhone). On part
d'un **Hôtel de ville** et de 4 habitants ; on **forme** les habitants à des
métiers, on **construit** (avec des chantiers qui prennent du temps), on gère
**nourriture, eau, bois, pierre, céréales, farine, outils**, la **santé** et le
**bonheur**, on améliore l'**Hôtel de ville** (6 niveaux) pour débloquer
bâtiments, métiers et compétences, et on **colonise** la planète avec des
avant‑postes. Événements aléatoires à choix, objectifs avec récompenses,
didacticiel guidé, personnalisation (couleurs, ciel, nom, taille de planète,
anneaux, lune). Style visuel « Diorama doux » (crème, corail, pastel).

## 2. Technique
- **Godot 4.7.2 stable**, GDScript, rendu **Mobile** (`project.godot`).
- Écran **390 × 844** (portrait), `stretch = canvas_items`, safe area gérée.
- Simulation à **pas fixe** : 10 ticks/s, **600 ticks = 1 jour = 60 s en x1**.
  Vitesses : pause, x1, x2, x4.
- **Simulation séparée du rendu** : `scripts/simulation/` n'utilise aucun Node.
- Sauvegarde JSON dans `user://savegame.json` (compacte, écriture atomique,
  copie `.bak`), réglages appareil dans `user://settings.json`.
- Tests headless maison : `tests/run_tests.gd` exécute `tests/unit/test_*.gd`
  (toute méthode `test_*`), assertions dans `tests/test_case.gd`.

## 3. Carte des fichiers
```
project.godot              Réglages Godot, autoloads (Loc, UserSettings, GameState)
VERSION                    Version « majeur.mineur » (ex. 0.6) ; le 3e nombre = n° de build auto
scenes/main.tscn           Scène racine (script scripts/main.gd)
scripts/
  main.gd                  Assemble ciel, lumière, planète, décors, HUD ; applique l'apparence
  core/
    game_state.gd          Autoload GameState : charge data/*.json dans `config`, crée la
                           Simulation, boucle à pas fixe, autosave, progression hors ligne,
                           new_world(options), seed_from_text()
    save_manager.gd        Enveloppe versionnée {version, saved_at_unix, game} + migrations
    user_settings.gd       Autoload UserSettings : vibrations, langue, nuages, contours, ciel
    localization.gd        Autoload Loc : charge data/locale/*.json comme traductions
    config.gd              Lecture JSON
  simulation/              ⚠️ logique pure, testée
    simulation.gd          Temps, jours, vitesse, planète, économie, objectifs, événements,
                           didacticiel (étape), personnalisation, to_dict/from_dict
    economy.gd             Stocks, bâtiments, production/consommation, chaînes, ouvriers
                           formés par métier, Hôtel de ville (niveaux, compétences),
                           chantiers, territoire, besoins (eau, santé, bonheur), migrations
    hex_grid.gd            Grille hexagonale sphérique (polyèdre de Goldberg : 10f²+2 cases)
    planet_generator.gd    Génération procédurale (terrain, fertilité, ressources) par graine
    planet_state.gd        Données par case : terrain, fertilité, ressources, pollution, bâtiment
    objectives.gd          Progression et récompenses des objectifs
    events.gd              Événements aléatoires (tirage pondéré, effets des choix)
    fixed_stepper.gd       Accumulateur temps réel → ticks
  render/
    planet_view.gd         Planète 3D : terrain, mer, végétation, bâtiments, sélection,
                           placement, caméra (rotation inertie, pincement, inclinaison)
    terrain_builder.gd     Terrain organique lisse (échantillonnage hauteur/couleur partout)
    building_meshes.gd     Modèles 3D arrondis des bâtiments (formes primitives en code)
    life.gd                Habitants qui marchent, oiseaux, fumées
  ui/
    design.gd              Système de design : couleurs, polices, styles, thème
    ui_kit.gd              Petits composants (labels, grilles de choix, pastilles couleur)
    hud.gd                 Toute l'interface en jeu (pastilles, barre du bas, menus,
                           Village/Mairie/Habitants/Objectifs, didacticiel, événements)
    start_menu.gd          Écran d'accueil + création de planète
  platform/haptics.gd      Vibrations
  dev/screenshot_runner.gd Captures automatiques (CI uniquement)
data/                      ⚠️ presque tout l'équilibrage se fait ici (voir 04_DONNEES_DU_JEU.md)
tests/unit/                Tests (simulation, économie, Hôtel de ville, données, textes…)
assets/icons/              Icône de l'app (PNG 1024 sans transparence) + icônes UI (SVG 64×64)
ci/                        Scripts de la CI (installer Godot, tests, IPA, release, bundle)
.github/workflows/         tests.yml, ios-unsigned.yml, screenshots.yml, chatgpt-bundle.yml,
                           ios-testflight.yml (optionnel, compte Apple payant)
```

## 4. Comment les systèmes s'enchaînent
- `GameState._ready()` charge `data/*.json` dans `config`, puis charge la
  sauvegarde (ou crée une planète). Chaque frame : `stepper.advance()` →
  `sim.run_ticks(n)`.
- `Simulation.step()` : `economy.update(1 jour / 600)` ; à chaque nouveau jour :
  `economy.daily_update()` (repousse des forêts, bonheur/santé, naissances,
  famine…), objectifs, événement aléatoire éventuel.
- `Economy.update(dt_jours)` : avance chantiers / amélioration de l'Hôtel de
  ville / formations, répartit les **ouvriers formés** (par métier et
  priorité), produit/consomme (l'entrée la plus rare limite la sortie),
  applique fertilité, outils (+25 %), bonus près de l'eau, compétences, puis la
  consommation des habitants (nourriture, eau).
- Signaux de `Economy` : `changed` (bâtiments → rafraîchir la 3D),
  `alert(clé)`, `construction_done(case)`, `level_up(niveau)`,
  `training_done(métier)`. Signaux de `Simulation` : `objective_completed`,
  `event_started`, `day_passed`.
- Le HUD lit l'état (`GameState.sim.economy…`) et appelle les actions
  (`build`, `train`, `upgrade_townhall`, `demolish`, `upgrade`).

## 5. Sauvegardes (ne jamais les casser)
- Format : `{"version": 1, "saved_at_unix": …, "game": sim.to_dict()}`.
- `Simulation.from_dict()` et `Economy.from_dict()` lisent chaque champ avec une
  **valeur par défaut** : une vieille sauvegarde sans le champ continue de
  marcher. Exemples existants : eau ajoutée (Phase 3), passage du feu de camp
  central à l'Hôtel de ville avec formation automatique des ouvriers
  (`Economy._migrate_to_townhall()`).
- Si un changement de format ne peut pas se faire par défaut : incrémenter
  `SAVE_VERSION` dans `save_manager.gd` et ajouter `_migrate_vN_to_vN+1`.

## 6. Tests et CI
- `tests.yml` (chaque push) : télécharge Godot 4.7.2, `--import`, lance
  `tests/run_tests.gd` (échoue si un test échoue **ou** si « SCRIPT ERROR » /
  « Parse Error » apparaît), puis lance le vrai jeu 120 frames (smoke test :
  échoue sur toute ligne `ERROR:`).
- `ios-unsigned.yml` (push sur la branche, sauf fichiers .md et docs/) :
  tests → export Godot → `xcodebuild` sans signature → `MiniPlanete.ipa` →
  **release GitHub `build-N`** avec `source.json` (source AltStore). Garde les 5
  dernières.
- `screenshots.yml` : lance le jeu dans un écran virtuel et publie des captures
  dans la release `screenshots` (accueil, jeu, construire, besoins, réglages,
  village, vue rapprochée, vue large).
- `chatgpt-bundle.yml` : régénère ce dossier et le publie dans la release
  `chatgpt`.
- Tests importants qui vérifient les données : mêmes clés FR/EN, chaque
  bâtiment a une icône `assets/icons/ui/<id>.svg` et ses textes
  (`name_key`, `desc_key`, `short_key`), chaque métier existe, chaque niveau
  d'Hôtel de ville est atteignable, les bâtiments du didacticiel sont
  abordables au départ.

## 7. Pièges Godot déjà rencontrés (à éviter)
1. **Les tableaux « Packed » (PackedVector3Array…) sont copiés** quand on les
   passe à une fonction : modifier dans une fonction un tableau reçu en
   paramètre ne change pas l'original. Utiliser `Array[Vector3]` typé.
2. **Faces avant = sens horaire** dans Godot : `MeshBuffer.add_tri()` et
   `terrain_builder.gd` réorientent les triangles vers l'extérieur.
3. `SphereMesh` avec `is_hemisphere = true` va de **y = 0 à y = height**.
4. Assigner un littéral `[...]` à une variable `Array[Control]` typée déjà
   déclarée peut échouer : utiliser `append_array([...])`.
5. `match` avec des constantes d'un autre script (`Economy.ERR_X`) : préférer
   des `if / elif`.
6. Accéder à une constante via une **instance** (`eco.ERR_X`) a planté : utiliser
   la chaîne ou `Economy.ERR_X` (script préchargé).
7. Inférence `var x :=` sur une expression `Variant` (objet non typé) : donner
   le type explicitement (`var x: bool = …`).
8. Pas d'émojis ni de flèches (→) dans les textes : la police ne les a pas
   forcément. Utiliser « : », « · », « + ».
9. L'interface doit tenir dans **390 px de large** : `clip_text = true` sur les
   boutons, peu de colonnes. Vérifier avec les captures d'écran.
10. Ne jamais appeler `GameState` depuis `scripts/simulation/` (logique pure).
11. Les SVG d'icônes sont importés par Godot : 64×64, couleurs pleines, pas de
    texte.

## 8. Rendu 3D — repères
- Rayon de la planète = 1. Taille de case ≈ `terrain.spacing` (radians).
  Objets mis à l'échelle par `_object_scale = 7.5 / fréquence`.
- `terrain.sample(dir, case)` → `[rayon, couleur, case]` ; `cell_top(case)` =
  hauteur où poser un bâtiment. La mer est une sphère de rayon 1 (shader).
- Tout objet répété (arbres, rochers, fleurs, habitants, oiseaux) est dans
  une **MultiMesh** (1 appel de dessin par type) : garder ce principe.
- Couleurs du terrain : `data/terrains.json` + palettes dans
  `data/customization.json` ; toits : couleur du village (`accent`).

## 9. Interface — repères
- Couleurs et styles : **uniquement** via `scripts/ui/design.gd`.
- Panneaux (« sheets ») : un seul visible à la fois (`_show_sheet`). Toute
  nouvelle zone cliquable doit être ajoutée à `_blocking` (sinon le toucher
  traverse vers la planète).
- Le didacticiel est décrit dans `data/tutorial.json` (conditions :
  `next`, `rotate`, `zoom`, `select`, `building:<id>:<n>`,
  `trained:<métier>:<n>`, `village`, `speed`).
