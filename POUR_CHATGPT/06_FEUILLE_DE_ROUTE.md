# Feuille de route et état du projet

## Déjà fait (version 0.6.x)
- Planète hexagonale (Goldberg) 642 / 1442 / 2562 / 4002 cases, générée par
  graine (océans, relief, palette, graine partageable).
- Terrain 3D organique, mer animée, végétation, rochers, fleurs, nuages,
  ciel en dégradé (5 ambiances), halo, jour/nuit, anneaux et lune.
- Habitants qui marchent, oiseaux, fumées, arbres au vent.
- Hôtel de ville (6 niveaux, compétences), formation aux 9 métiers, chantiers
  avec bâtisseurs, avant‑postes, territoire.
- 15 bâtiments de l'âge de pierre, chaînes (céréales → farine → pain ;
  bois + pierre → outils), eau, santé, bonheur, productivité.
- Objectifs, événements à choix, didacticiel guidé, écran d'accueil.
- Interface « Diorama doux », réglages (langue FR/EN, vibrations, nuages,
  contours, ciel), sauvegarde auto + migrations, progression hors ligne.
- CI : tests, IPA gratuit + source AltStore, captures d'écran, ce dossier.

## Prochaines étapes prévues (dans l'ordre conseillé)
1. **Science et arbre technologique** : ressource « connaissance » (ex.
   bâtiment « Cercle des anciens »), ~40 technologies réparties sur 6 âges,
   chacune débloquant bâtiments/bonus ; écran « Technologies ».
2. **Âges** : Antiquité, Médiéval, Industriel, Moderne, Futuriste. Idée :
   l'Hôtel de ville niveau 6 + certaines technologies font passer à l'âge
   suivant (nouveaux niveaux 7‑12, nouvelle palette et nouveaux modèles 3D,
   musique différente).
3. **Environnement** : pollution par case qui se diffuse, température
   globale, fonte des glaces, montée des eaux ; solutions (forêts, énergies
   propres). Le champ `pollution` existe déjà dans `planet_state.gd`.
4. **Énergie** (Industriel+) : électricité, pétrole et uranium (déjà présents
   comme ressources cachées sur les cases).
5. **Catastrophes** : sécheresse, tremblement de terre, épidémie, météorite.
6. **Finition** : musique d'ambiance par âge et sons doux (CC0 ou générés),
   succès, appui long sur un bâtiment (améliorer/détruire), écran de
   statistiques, icône finale, optimisation (LOD, moins de nœuds par
   bâtiment via MultiMesh).
7. **Publication** (facultative) : fiche App Store, politique de
   confidentialité, captures.

## Idées en réserve
- Routes automatiques entre bâtiments, saisons, animaux (moutons, poissons),
  bateaux, comptoirs commerciaux entre avant‑postes, merveilles.
- Mode photo, partage de la graine de planète.

## Points d'attention connus
- Planète « Immense » (4002 cases) : génération et terrain plus lourds,
  surveiller la fluidité sur iPhone ancien.
- Les comptes Apple gratuits imposent un renouvellement tous les 7 jours
  (voir `03_METTRE_A_JOUR_ALTSTORE.md`).
- Équilibrage pas encore testé longuement sur iPhone : ajuster
  `townhall.json` / `buildings.json` selon le ressenti.
