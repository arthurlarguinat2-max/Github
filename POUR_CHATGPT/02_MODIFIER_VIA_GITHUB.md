# Modifier le jeu depuis l'iPhone avec GitHub

Pas besoin d'ordinateur : tout se fait dans **Safari** sur github.com.

> **Astuce Safari :** si l'écran GitHub est trop petit ou qu'un bouton manque,
> touche **« aA »** dans la barre d'adresse → **Demander le site pour ordinateur**.

## 1. Modifier un fichier existant
1. Ouvre <https://github.com/arthurlarguinat2-max/Github> (connecte‑toi).
2. Vérifie en haut à gauche que la branche est
   **`claude/mini-planete-ios-godot-9vnfsb`** (c'est la seule et la principale).
3. Navigue jusqu'au fichier (ex. `data` → `buildings.json`).
4. Touche l'icône **crayon ✏️** (« Edit this file »).
5. **Sélectionne tout le contenu** (appui long → Tout sélectionner) et
   **colle** la version complète donnée par ChatGPT.
6. Touche **Commit changes…** (en haut à droite) → laisse un court message
   (ex. « Ajoute le moulin à vent ») → coche **Commit directly to the
   `claude/mini-planete-ios-godot-9vnfsb` branch** → **Commit changes**.

## 2. Créer un nouveau fichier
1. Va dans le dossier voulu (ex. `scripts/render`).
2. **Add file** → **Create new file**.
3. Tape le nom exact donné par ChatGPT (ex. `fireflies.gd`). Pour créer un
   dossier, tape `dossier/nom.gd`.
4. Colle le contenu → **Commit changes**.

Pour une **icône SVG** : même chose dans `assets/icons/ui/` avec un nom en
`.svg` (ChatGPT peut écrire le code SVG).

## 3. Plusieurs fichiers d'un coup
Fais un commit par fichier, **sans attendre** entre eux : GitHub annule
automatiquement les fabrications intermédiaires et garde la dernière.

## 4. Vérifier que tout va bien
1. Onglet **Actions** du dépôt : <https://github.com/arthurlarguinat2-max/Github/actions>
2. Chaque modification lance :
   - **Tests** (~30 s) ;
   - **iOS – version gratuite (SideStore)** (~3‑6 min) : fabrique l'app et la publie ;
   - **Captures d'écran** (~2 min) : photos du jeu ;
   - **Dossier ChatGPT** (~20 s) : met à jour les fichiers de ce dossier.
3. ✅ vert = c'est publié, tu peux faire la mise à jour dans AltStore.
   🟠 = en cours. ❌ rouge = erreur.

## 5. En cas d'erreur ❌
1. Touche l'exécution en rouge → le job rouge (ex. « tests ») → l'étape rouge.
2. Fais défiler jusqu'aux lignes avec **✗**, **SCRIPT ERROR**, **Parse Error** ou
   **ERROR**. Copie ces lignes (et une dizaine autour).
3. Donne‑les à ChatGPT avec le prompt « Corriger une erreur de la CI » de
   `05_PROMPTS_CHATGPT.md`.
4. Le jeu déjà installé sur ton iPhone n'est **pas** touché : une version en
   erreur n'est jamais publiée.

## 6. Annuler une modification
1. Onglet **Code** → touche l'horloge **« xx commits »** (historique).
2. Ouvre le commit fautif → note les fichiers changés.
3. Pour chaque fichier : ouvre l'ancienne version (bouton **…** → **View file**
   sur le commit d'avant), copie tout, puis colle‑le dans le fichier actuel
   (étape 1) et commit.
   (Ou demande à ChatGPT de te redonner l'ancienne version complète.)

## 7. Voir le jeu sans l'installer
Après chaque modification, ouvre
<https://github.com/arthurlarguinat2-max/Github/releases/tag/screenshots> :
tu y trouves des captures du jeu (accueil, jeu, menus, vue rapprochée). Tu peux
les **donner à ChatGPT** pour qu'il juge le résultat visuel.

## 8. Changer la version affichée
Le fichier `VERSION` contient `majeur.mineur` (ex. `0.6`). Le 3e nombre (n° de
build) s'ajoute tout seul. Passe à `0.7` pour une grosse nouveauté.
