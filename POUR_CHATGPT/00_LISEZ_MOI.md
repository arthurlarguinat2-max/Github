# Mini Planète — dossier de reprise (pour ChatGPT ou toute IA)

Ce dossier contient **tout ce qu'il faut pour continuer à développer le jeu**
sans Claude : la description du projet, le code complet, comment modifier le
jeu depuis GitHub, et comment installer les mises à jour sur l'iPhone avec
AltStore.

---

## 👤 Pour toi (le joueur / propriétaire du projet)

### Ce qu'il faut donner à ChatGPT au début d'une conversation
1. **Ce fichier** (`00_LISEZ_MOI.md`) et **`01_PROJET.md`**.
2. Le ou les fichiers de code concernés par ta demande :
   | Ta demande concerne… | Donne ce fichier |
   |---|---|
   | règles du jeu, bâtiments, ressources, niveaux, textes, équilibrage | `CODE_1_SIMULATION_ET_DONNEES.md` |
   | 3D, planète, couleurs, menus, boutons, interface | `CODE_2_RENDU_ET_INTERFACE.md` |
   | fabrication de l'app, GitHub Actions, AltStore | `CODE_3_BUILD_ET_CI.md` |
   Dans le doute, donne les deux premiers.
3. Puis copie un des **prompts prêts à l'emploi** de `05_PROMPTS_CHATGPT.md`.

### Où trouver ces fichiers depuis l'iPhone
- **Toujours à jour (recommandé)** : la CI les régénère à chaque modification
  et les publie ici :
  - <https://github.com/arthurlarguinat2-max/Github/releases/download/chatgpt/00_LISEZ_MOI.md>
  - <https://github.com/arthurlarguinat2-max/Github/releases/download/chatgpt/01_PROJET.md>
  - <https://github.com/arthurlarguinat2-max/Github/releases/download/chatgpt/CODE_1_SIMULATION_ET_DONNEES.md>
  - <https://github.com/arthurlarguinat2-max/Github/releases/download/chatgpt/CODE_2_RENDU_ET_INTERFACE.md>
  - <https://github.com/arthurlarguinat2-max/Github/releases/download/chatgpt/CODE_3_BUILD_ET_CI.md>
  - et tous les autres guides de ce dossier, au même endroit :
    <https://github.com/arthurlarguinat2-max/Github/releases/tag/chatgpt>
- Ouvre le lien dans Safari → le fichier se télécharge dans l'app **Fichiers**
  → dans ChatGPT, touche **+** → **Fichiers** → choisis‑le.

### Le cycle de travail (tout depuis l'iPhone)
1. Tu demandes une modification à ChatGPT (avec les fichiers ci‑dessus).
2. ChatGPT te renvoie **les fichiers modifiés en entier**.
3. Tu les colles sur GitHub (voir `02_MODIFIER_VIA_GITHUB.md`).
4. GitHub teste, fabrique et publie la nouvelle version (~6 min).
5. Sur l'iPhone : **AltStore → My Apps → Update** (voir `03_METTRE_A_JOUR_ALTSTORE.md`).
6. Si GitHub affiche une ❌ : copie le message d'erreur et donne‑le à ChatGPT.

### Liens importants
| Quoi | Lien |
|---|---|
| Le dépôt | <https://github.com/arthurlarguinat2-max/Github> |
| Branche de travail (la seule, = branche principale) | `claude/mini-planete-ios-godot-9vnfsb` |
| Résultats des builds | <https://github.com/arthurlarguinat2-max/Github/actions> |
| Dernière version de l'app | <https://github.com/arthurlarguinat2-max/Github/releases/latest> |
| Source AltStore (à ajouter une fois) | `https://github.com/arthurlarguinat2-max/Github/releases/latest/download/source.json` |
| Captures d'écran automatiques | <https://github.com/arthurlarguinat2-max/Github/releases/tag/screenshots> |

---

## 🤖 Pour ChatGPT (ou toute IA qui reprend le projet)

Tu reprends **Mini Planète**, un jeu de gestion iPhone **natif** fait avec
**Godot 4.7.2 (GDScript, rendu Mobile)**. Le propriétaire n'a **qu'un iPhone**
(et parfois un Mac) : **il ne peut rien compiler ni tester lui‑même**. Toute la
vérification passe par **GitHub Actions** (tests headless + fabrication de
l'IPA + publication AltStore). Lis `01_PROJET.md` avant de coder.

### Règles à respecter absolument
1. **Renvoie toujours les fichiers modifiés EN ENTIER**, avec leur chemin
   exact (ex. `scripts/simulation/economy.gd`). Le propriétaire les copie‑colle
   sur GitHub : un extrait ou un « … reste inchangé » casse le jeu.
2. **Le moins de fichiers possible** par modification, et dis lesquels.
3. **Code en anglais, textes du jeu et explications en français.** Tout texte
   affiché passe par une clé dans `data/locale/fr.json` **et**
   `data/locale/en.json` (les deux doivent avoir exactement les mêmes clés :
   un test le vérifie).
4. **Ne jamais casser une sauvegarde existante** : tout nouveau champ doit avoir
   une valeur par défaut dans `from_dict()` (voir la section Sauvegardes de
   `01_PROJET.md`).
5. **Préfère modifier les données JSON** (`data/*.json`) plutôt que le code
   quand c'est possible (équilibrage, nouveaux bâtiments, niveaux…).
6. **Ajoute ou adapte un test** dans `tests/unit/` pour toute règle de jeu
   nouvelle (les tests tournent dans la CI à chaque modification).
7. Lis la liste **« Pièges Godot déjà rencontrés »** dans `01_PROJET.md` : ce
   sont des erreurs réelles qui ont déjà fait échouer la CI.
8. Pas de jeu web, pas de compte, pas de pub, 100 % hors ligne.
9. Les assets doivent être **faits maison** (formes en code, SVG écrits à la
   main) ou **CC0** et crédités dans `CREDITS.md`.
