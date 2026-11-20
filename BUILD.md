# Installer Mini Planète sur ton iPhone — avec seulement un iPhone

Pas besoin d'ordinateur. Tout se fait dans **Safari** sur ton iPhone, et la
compilation tourne sur les machines macOS de **GitHub Actions**.

**Ce que ça donne :** l'app arrive dans **TestFlight**, en privé. Toi seul
(et les personnes que tu invites) pouvez l'installer. **Rien n'est vendu ni
publié sur l'App Store** : une publication demanderait une soumission à Apple,
qui ne sera jamais faite sans ta demande.

**Coût :** compte Apple Developer, 99 $/an (obligatoire chez Apple pour
installer une app perso sans ordinateur).

**Tu n'as rien à fabriquer toi‑même :** le certificat et le profil de
signature sont créés automatiquement par GitHub au premier build, puis
rangés **chiffrés** (avec ton mot de passe) sur la branche `match-signing`
du dépôt.

> **Astuce Safari :** si une page Apple ou GitHub s'affiche mal, touche
> **« aA »** dans la barre d'adresse → **Demander le site pour ordinateur**.

---

## Étape 1 — Compte Apple Developer (depuis l'iPhone)

1. Installe l'app **Apple Developer** depuis l'App Store.
2. Ouvre‑la → **Compte** → connecte‑toi avec ton identifiant Apple →
   **S'inscrire maintenant** (Enroll), en tant que particulier.
   Le paiement se fait directement dans l'app.
3. Attends l'e‑mail de confirmation (de quelques minutes à 48 h).
4. Récupère ton **Team ID** : dans Safari, va sur
   <https://developer.apple.com/account> → **Membership details** →
   **Team ID** (10 caractères, ex. `AB12CD34EF`). Garde‑le dans Notes.

## Étape 2 — Choisir l'identifiant de l'app (Bundle ID)

Invente un identifiant unique, en minuscules, sans accent ni espace, par ex. :
`com.tonprenom.miniplanete`

Note‑le dans Notes. Il ne pourra plus changer. GitHub l'enregistrera
automatiquement chez Apple.

## Étape 3 — Créer la fiche privée dans App Store Connect

TestFlight a besoin d'une « fiche » d'app. Elle reste privée tant que tu ne
la soumets pas à la publication.

1. Safari → <https://appstoreconnect.apple.com/apps> (mode « site pour
   ordinateur » conseillé).
2. **+** → **Nouvelle app** :
   - Plateformes : **iOS**
   - Nom : `Mini Planète` (s'il est pris : `Mini Planète – Perso`)
   - Langue principale : **Français**
   - Identifiant de lot (Bundle ID) : choisis celui de l'étape 2.
     **S'il n'apparaît pas encore dans la liste :** fais d'abord l'étape 4,
     lance une fois le build (étape 7), qui échouera mais enregistrera le
     Bundle ID, puis reviens ici.
   - UGS (SKU) : `miniplanete001`
   - Accès utilisateur : **Accès complet**
3. **Créer**.

## Étape 4 — Clé API App Store Connect

Elle permet à GitHub de parler à Apple sans ton mot de passe.

1. Safari → <https://appstoreconnect.apple.com/access/integrations/api>
   (*Utilisateurs et accès* → *Intégrations* → *App Store Connect API*).
   La première fois : **Demander l'accès**, puis accepte.
2. **Générer une clé API** (ou **+**) :
   - Nom : `GitHub`
   - Accès : **Admin** (nécessaire pour que GitHub puisse créer le certificat)
3. Note dans Notes :
   - l'**ID de la clé** (ex. `2X9R4HXF34`),
   - l'**Issuer ID** affiché en haut de la page (long code avec des tirets).
4. Touche **Télécharger la clé API**. Apple ne la propose **qu'une seule fois** !
   Le fichier `AuthKey_XXXX.p8` arrive dans l'app **Fichiers** → *Téléchargements*.

**Copier le contenu de la clé :**
1. App **Fichiers** → *Téléchargements* → appui long sur `AuthKey_XXXX.p8`
   → **Renommer** → remplace `.p8` par `.txt` (confirme « Utiliser .txt »).
2. Ouvre le fichier `.txt` → appui long sur le texte → **Tout sélectionner**
   → **Copier**. Le texte commence par `-----BEGIN PRIVATE KEY-----`
   et finit par `-----END PRIVATE KEY-----`.
3. Garde ce fichier dans un endroit sûr (iCloud Drive), ne le partage jamais.

## Étape 5 — Choisir un mot de passe de chiffrement

Invente un mot de passe long (ex. 4 mots au hasard), il chiffrera le
certificat stocké dans le dépôt. Garde‑le dans ton gestionnaire de mots de
passe. **Si tu le perds**, il suffira d'en choisir un autre et de supprimer
la branche `match-signing` (un nouveau certificat sera créé).

> Conseil : rends le dépôt **privé** si ce n'est pas déjà le cas
> (dépôt GitHub → **Settings** → tout en bas, *Change visibility*).
> Les fichiers sont chiffrés de toute façon, mais c'est plus sûr.

## Étape 6 — Créer les 6 secrets GitHub

Safari → ton dépôt sur github.com (mode « site pour ordinateur ») →
**Settings** → **Secrets and variables** → **Actions** →
**New repository secret**. Crée exactement :

| Nom du secret | Contenu |
|---|---|
| `APPLE_TEAM_ID` | ton Team ID (étape 1) |
| `APP_BUNDLE_ID` | ton Bundle ID, ex. `com.tonprenom.miniplanete` (étape 2) |
| `ASC_KEY_ID` | l'ID de la clé (étape 4) |
| `ASC_ISSUER_ID` | l'Issuer ID (étape 4) |
| `ASC_KEY_P8` | tout le texte de la clé, lignes BEGIN/END comprises (étape 4) |
| `MATCH_PASSWORD` | ton mot de passe de chiffrement (étape 5) |

Les noms sont sensibles à la casse : copie‑les tels quels.

## Étape 7 — Lancer la construction

Safari → ton dépôt → onglet **Actions** → **iOS → TestFlight** →
**Run workflow** → branche `claude/mini-planete-ios-godot-9vnfsb` (ou `main`
plus tard) → **Run workflow**.

- Durée : ~15–25 min. Rond orange = en cours, coche verte = réussi.
- Le numéro de build augmente tout seul, la version vient du fichier `VERSION`.
- En cas de croix rouge : préviens‑moi, je lirai les logs et corrigerai.

## Étape 8 — Installer sur l'iPhone

10 à 30 min après la coche verte (Apple traite le build) :

1. Installe l'app **TestFlight** depuis l'App Store.
2. Safari → <https://appstoreconnect.apple.com/apps> → Mini Planète →
   **TestFlight** → **Testeurs internes** → **+** → crée un groupe
   (ex. « Moi ») et ajoute‑toi.
3. Tu reçois une invitation par e‑mail → ouvre‑la sur l'iPhone →
   TestFlight → **Installer**.

Chaque nouveau build apparaît ensuite dans TestFlight → **Mettre à jour**.
Ta partie est conservée entre les mises à jour.
Un build TestFlight reste installable **90 jours** : il suffit d'en relancer
un (étape 7) de temps en temps.

> Si Apple demande un « questionnaire de conformité export » : réponds que
> l'app n'utilise **aucun chiffrement** (c'est déjà déclaré dans le build).

---

## Dépannage

| Symptôme dans les logs | Cause probable |
|---|---|
| `Missing secret …` | secret absent ou mal nommé (sensible à la casse) |
| `ASC_KEY_P8 is not a valid .p8 key` | le texte collé est incomplet : recopie tout, lignes BEGIN/END comprises |
| `Authentication credentials are missing or invalid` | `ASC_KEY_ID`, `ASC_ISSUER_ID` ou clé incorrects |
| `… not allowed to create certificates` / `forbidden` | la clé API n'a pas le rôle **Admin** : recrée‑la (étape 4) |
| `Could not find App with bundle identifier` | la fiche de l'étape 3 n'existe pas ou utilise un autre Bundle ID |
| `You already have a current Distribution certificate` | limite Apple atteinte : sur developer.apple.com → *Certificates*, révoque un ancien certificat de distribution inutilisé |
| `Invalid password` / erreur de déchiffrement | `MATCH_PASSWORD` différent de celui du premier build |
| Erreur d'export Godot | la version `GODOT_VERSION` n'existe pas : mets la dernière stable |

## Renouvellement annuel

Le certificat expire après 1 an. Il suffit alors de supprimer la branche
`match-signing` (dépôt → *Branches*) et de relancer un build : un nouveau
certificat est créé automatiquement.

## Changer de version de Godot

Une seule valeur à modifier : `GODOT_VERSION` en tête des deux fichiers de
`.github/workflows/`.
