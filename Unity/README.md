# Mini Planète pour Unity — version de développement iPhone

Le dossier `Unity/` est un projet Unity 6 (6000.0.62f1). La scène de départ est `Assets/Scenes/Planet.unity`. Les modèles du village, les quatre grilles de la planète et le premier monde proviennent du jeu Godot. Ils sont déjà inclus. Le jeu tourne ensuite en C# dans Unity.

## Depuis l’iPhone

Le workflow **Mini Planète Unity · iPhone** sur la branche `unity/mini-planete-ios` teste la simulation, exporte le projet Xcode avec GameCI et fabrique une IPA sur macOS. L’export GameCI demande une activation Unity. Pour Unity Personal, configurer les secrets d’Actions `UNITY_LICENSE`, `UNITY_EMAIL` et `UNITY_PASSWORD` selon [la documentation GameCI](https://game.ci/docs/github/activation/). Après activation, relancer les tâches en échec. La préversion reçoit son propre tag `unity-N` et son propre identifiant iOS `com.miniplanete.unitypreview`. Télécharger `MiniPlanete-Unity.ipa` depuis cette préversion et l’ouvrir dans AltStore.

Pour travailler uniquement via un compte Unity Cloud, connecter le dépôt dans **DevOps → Build Automation**, choisir la même branche, le sous-dossier `Unity`, la plateforme iOS et l’éditeur indiqué ci-dessus. La compilation et la signature hébergées dépendent du compte et des identifiants de signature configurés dans Unity Cloud.

## Jeu et sauvegardes

Glisser pour faire tourner, pincer pour zoomer, toucher une case pour construire. L’onglet Village gère les formations et les niveaux de mairie. Le jeu sauvegarde dans `unity-village.json` au passage en arrière-plan et toutes les 30 secondes. Les sauvegardes Unity sont indépendantes de l’app Godot.

Le lecteur accepte une copie du fichier Godot `savegame.json` version 1 avec données de planète, mairie et métiers, placée dans le dossier Documents de la nouvelle app avant la création de sa première sauvegarde Unity. Il utilise les mêmes indices de cases pour les fréquences 8, 12, 16 et 20. Le projet ne transfère pas automatiquement des fichiers entre les deux applications iOS.

## Vérifications

À la racine du dépôt, `dotnet run --project ci/unity/SimulationChecks.csproj -- Unity/Assets/Resources` exécute les contrôles de simulation et de reprise. Pour régénérer les modèles et les grilles après un changement côté Godot, ouvrir le projet Godot 4.7.2 puis exécuter `godot --headless --path . --script res://ci/unity/bake.gd`.
