# Les données du jeu (modifiables sans toucher au code)

Presque tout l'équilibrage est dans `data/`. Après une modification, la CI
vérifie automatiquement que les fichiers sont valides (tests).

| Fichier | Contenu |
|---|---|
| `game_config.json` | Vitesse du temps, autosave, hors ligne, planète (taille par défaut, océans, relief), économie (consommation, bonheur/santé), événements |
| `buildings.json` | Bâtiments, coûts, production, ouvriers, métiers, temps de construction, départ du village |
| `townhall.json` | Les 6 niveaux de l'Hôtel de ville : coût, conditions, durée, bâtiments autorisés (et combien), métiers, compétences |
| `professions.json` | Métiers : coût et durée de formation, icône |
| `terrains.json` | Types de terrain : couleur, hauteur, fertilité, ressources, repousse |
| `resources.json` | Noms des ressources, ressources cachées |
| `objectives.json` | Objectifs et récompenses |
| `events.json` | Événements aléatoires et leurs choix |
| `tutorial.json` | Étapes du didacticiel |
| `customization.json` | Tailles de planète, océans, reliefs, palettes, couleurs du village, ciels, syllabes des noms |
| `locale/fr.json`, `locale/en.json` | Tous les textes (mêmes clés dans les deux) |

## Unités
- **1 jour de jeu = 60 secondes en vitesse x1.** Les productions sont « par jour ».
- `build_days: 0.5` = 30 s de construction en x1.

## Un bâtiment (`buildings.json`)
```json
"gatherer": {
  "name_key": "BLD_GATHERER", "desc_key": "BLD_GATHERER_DESC", "short_key": "BLD_GATHERER_SHORT",
  "category": "food",            // onglet : housing | food | resources | services
  "order": 10,                   // ordre dans le menu
  "priority": 1,                 // qui reçoit les ouvriers en premier (plus petit = d'abord)
  "cost": {"wood": 5},
  "build_days": 0.25,
  "workers": 2, "profession": "gatherer",   // habitants formés nécessaires
  "produces": {"food": 6},       // par jour avec tous les ouvriers
  "consumes": {},                // entrées par jour (ex. {"flour": 8, "wood": 1})
  "fertility_bonus": true,       // production × (0,4 + fertilité)
  "tool_bonus": true,            // +25 % s'il y a des outils
  "extracts": "wood",            // prend la ressource sur sa case et les voisines
  "water_bonus": 1.5,            // × 1,5 à côté de l'eau
  "housing": 0, "happiness": 0, "health": 0, "growth_bonus": 0,
  "territory": 1,                // rayon de territoire (en cases)
  "upgrade_to": "longhouse",     // amélioration possible
  "buildable": true,             // false = absent du menu (ex. Hôtel de ville)
  "terrains": ["plains", "forest", "beach"]
}
```

## Ajouter un nouveau bâtiment : la check‑list
1. `data/buildings.json` : la définition (ci‑dessus).
2. `data/townhall.json` : dans `buildings` de chaque niveau où il est
   autorisé, le nombre maximum (ex. `"windmill": 2`). **Absent = verrouillé.**
3. S'il a des ouvriers : un métier dans `professions.json` (ou un existant), et
   ce métier dans la liste `professions` des niveaux concernés.
4. `data/locale/fr.json` **et** `en.json` : `BLD_X`, `BLD_X_DESC`, `BLD_X_SHORT`
   (+ le nom du métier `PROF_X` si nouveau).
5. Icône `assets/icons/ui/<id>.svg` (64×64, formes simples, pas de texte).
6. Modèle 3D : un `"<id>":` dans `create()` de `scripts/render/building_meshes.gd`
   (sinon il apparaît comme une boule rouge). Utiliser les formes arrondies
   existantes (`_round_house`, `_dome`, `_capsule`, `_sphere`, `_torus`…).
7. (Optionnel) Un objectif dans `objectives.json`.
Les tests vérifient les points 3 à 5.

## Un niveau d'Hôtel de ville (`townhall.json`)
```json
{"level": 3, "cost": {"wood": 80, "stone": 50}, "requires": {"population": 12}, "days": 1.5,
 "housing": 8, "territory": 5, "builders": 2, "training_slots": 2,
 "buildings": {"hut": 9, "mill": 1, "...": 1},
 "professions": ["water_carrier", "gatherer", "..."],
 "perks": [{"id": "builders", "name_key": "PERK_BUILDERS", "build_speed": 1.25}]}
```
Compétences possibles : `"production": {"food": 1.1}`, `"build_speed"`,
`"training_speed"`, `"happiness"`. Elles s'additionnent d'un niveau à l'autre.
Un test vérifie que chaque niveau ne coûte que des ressources produites par les
bâtiments du niveau précédent.

## Ajouter un 7e niveau (ou un nouvel âge)
Ajouter un objet dans `levels` (avec `"level": 7`) ; le jeu s'adapte seul
(niveau max, écran Mairie, objectifs). Penser aux textes des compétences.

## Un événement (`events.json`)
```json
{"id": "storm", "title_key": "EV_STORM", "text_key": "EV_STORM_TEXT", "weight": 2, "min_day": 6, "min_population": 0,
 "choices": [{"label_key": "EV_STORM_A", "effects": {"wood": -15}},
             {"label_key": "EV_STORM_B", "effects": {"happiness": -8, "health": -5}}]}
```
Effets possibles : n'importe quelle ressource (+/−), `population`, `happiness`,
`health`. Chance quotidienne et premier jour : `game_config.json` → `event_settings`.

## Un objectif (`objectives.json`)
Types : `population`, `building` (+ `target`), `buildings_total`, `happiness`,
`health`, `day`, `stock` (+ `target`), `townhall`, `trained`.

## Le didacticiel (`tutorial.json`)
Conditions : `next` (bouton Suivant), `rotate`, `zoom`, `select`,
`building:<id>:<nombre>`, `trained:<métier>:<nombre>`, `village`, `speed`.
`highlight` fait clignoter : `build`, `village`, `speed`, `needs`.
