# Prompts prêts à copier dans ChatGPT

Joins toujours **`00_LISEZ_MOI.md`**, **`01_PROJET.md`** et le ou les fichiers
`CODE_*.md` utiles (voir le tableau du LISEZ_MOI). Pour une modification de
données, ajoute `04_DONNEES_DU_JEU.md`.

---

## 1. Démarrer une session
```
Tu reprends le développement de mon jeu iPhone « Mini Planète » (Godot 4.7.2,
GDScript). Lis les fichiers joints : 00_LISEZ_MOI.md (règles), 01_PROJET.md
(architecture et pièges) et le code. Je n'ai qu'un iPhone : je copie-colle tes
fichiers sur GitHub, la CI teste et publie, puis je mets à jour via AltStore.
Règles : renvoie chaque fichier modifié EN ENTIER avec son chemin exact, le
moins de fichiers possible, textes du jeu en français ET anglais (mêmes clés),
ne casse jamais une sauvegarde, ajoute un test pour toute nouvelle règle.
Confirme que tu as compris en 3 lignes, puis attends ma demande.
```

## 2. Ajouter une fonctionnalité
```
Je veux : [décris ce que tu veux, ce que le joueur voit et fait].
Avant de coder, propose un plan court (fichiers touchés, données ajoutées,
impact sur les sauvegardes). Après mon accord, donne les fichiers complets,
dans l'ordre où je dois les créer/modifier sur GitHub, et ce que je dois voir
dans le jeu pour vérifier.
```

## 3. Ajouter un bâtiment
```
Ajoute le bâtiment « [nom] » : [rôle, coût, production, ouvriers, niveau de
l'Hôtel de ville qui le débloque, terrains]. Suis la check-list de
04_DONNEES_DU_JEU.md (données, niveaux, métier, textes FR/EN, icône SVG,
modèle 3D arrondi dans building_meshes.gd, objectif éventuel). Donne chaque
fichier complet.
```

## 4. Équilibrer le jeu
```
Le jeu est [trop lent / trop dur / trop facile] parce que [observation].
Propose des changements UNIQUEMENT dans data/*.json (pas de code), explique
l'effet attendu, puis donne les fichiers JSON complets modifiés.
```

## 5. Corriger une erreur de la CI
```
La CI GitHub a échoué après ma dernière modification. Voici le nom du job et
les lignes d'erreur :
[colle ici les lignes avec ✗ / SCRIPT ERROR / Parse Error / ERROR]
Trouve la cause (pense aux pièges Godot de 01_PROJET.md) et donne les
fichiers corrigés en entier.
```

## 6. Corriger un bug vu dans le jeu
```
Dans le jeu, [ce qui se passe], alors que je m'attendais à [ce qui devrait
se passer]. Ça arrive quand [étapes]. [Capture d'écran jointe si possible.]
Trouve la cause dans le code joint et donne les fichiers corrigés en entier.
Ajoute un test qui reproduit le bug si c'est une règle du jeu.
```

## 7. Changer l'apparence
```
Je veux changer [couleurs / boutons / 3D …] : [description]. Les couleurs et
styles de l'interface sont dans scripts/ui/design.gd, la 3D dans
scripts/render/. L'écran fait 390 px de large : rien ne doit déborder.
Voici les captures actuelles : [joins des images de la release
« screenshots »]. Donne les fichiers complets.
```

## 8. Passer à la suite (âges suivants)
```
Lis la feuille de route (06_FEUILLE_DE_ROUTE.md). Propose la prochaine
étape en 5-8 points maximum, découpée en petites mises à jour que je peux
publier une par une (chacune jouable). On commence par la première après
mon accord.
```

## Conseils
- **Une demande à la fois**, puis publie et teste avant la suivante.
- Si ChatGPT oublie un fichier ou donne un extrait (« … »), demande :
  « Redonne le fichier [chemin] en entier, sans rien omettre. »
- Si une conversation devient longue, ouvre‑en une nouvelle avec les fichiers
  **à jour** (liens de la release `chatgpt`, voir LISEZ_MOI).
