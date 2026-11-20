# Compiler Mini Planète pour iPhone — sans Mac

Toute la compilation iOS se fait sur **GitHub Actions** (machine macOS louée par
GitHub) avec **fastlane**. Toi, tu n'as besoin que d'un PC (Windows ou Linux),
d'un navigateur et d'**OpenSSL**.

> Sous Windows, OpenSSL est fourni avec **Git for Windows** : ouvre « Git Bash »
> et toutes les commandes ci‑dessous fonctionnent telles quelles.

Les deux workflows :

| Workflow | Quand | Ce qu'il fait |
|---|---|---|
| `Tests` (`.github/workflows/tests.yml`) | chaque push | tests headless de la simulation + lancement de la scène principale (Linux) |
| `iOS → TestFlight` (`.github/workflows/ios-testflight.yml`) | tag `v*` ou bouton manuel | export Godot → Xcode → signature → envoi sur TestFlight (macOS) |

---

## Étape 1 — Compte Apple Developer

1. Inscris‑toi sur <https://developer.apple.com/programs/> (99 $/an). L'activation
   peut prendre jusqu'à 48 h.
2. Note ton **Team ID** : <https://developer.apple.com/account> → *Membership
   details* → *Team ID* (10 caractères, ex. `AB12CD34EF`).
   → secret **`APPLE_TEAM_ID`**

## Étape 2 — Identifiant de l'app (Bundle ID)

1. <https://developer.apple.com/account/resources/identifiers/list> → **+**
2. *App IDs* → *App* → Continue.
3. Description : `Mini Planete` ; Bundle ID **Explicit** : par ex.
   `com.tonnom.miniplanete` (minuscules, pas d'accent ; il ne pourra plus changer).
4. Aucune « Capability » n'est nécessaire → *Continue* → *Register*.
   → secret **`APP_BUNDLE_ID`** (ex. `com.tonnom.miniplanete`)

## Étape 3 — Certificat de distribution (sans Mac, avec OpenSSL)

Travaille dans un dossier **hors du dépôt Git** (ex. `~/apple-signing/`) : ces
fichiers sont secrets.

```bash
mkdir -p ~/apple-signing && cd ~/apple-signing

# 3.1 Clé privée (à garder précieusement, ne jamais la partager)
openssl genrsa -out distribution.key 2048

# 3.2 Demande de certificat (CSR) — remplace l'e-mail et le nom
openssl req -new -key distribution.key -out distribution.csr \
  -subj "/emailAddress=ton@email.com/CN=Ton Nom/C=FR"
```

3.3 Sur <https://developer.apple.com/account/resources/certificates/list> → **+**
→ **Apple Distribution** → *Continue* → envoie `distribution.csr` → télécharge
le fichier `distribution.cer`, place‑le dans `~/apple-signing/`.

```bash
# 3.4 Conversion .cer (DER) -> .pem
openssl x509 -inform der -in distribution.cer -out distribution.pem

# 3.5 Création du .p12 (certificat + clé). Choisis un mot de passe solide.
#     -legacy est indispensable avec OpenSSL 3 pour que macOS sache l'importer.
openssl pkcs12 -export -legacy \
  -inkey distribution.key -in distribution.pem \
  -out distribution.p12 -name "Apple Distribution"
```

> Si `-legacy` est refusé, ton OpenSSL est en version 1.x : retire simplement l'option.

- Le contenu base64 du `.p12` → secret **`IOS_DIST_CERT_P12_BASE64`**
- Le mot de passe choisi → secret **`IOS_DIST_CERT_PASSWORD`**

## Étape 4 — Profil de provisionnement App Store

1. <https://developer.apple.com/account/resources/profiles/list> → **+**
2. *Distribution* → **App Store Connect** → *Continue*.
3. Choisis ton App ID (`com.tonnom.miniplanete`) → *Continue*.
4. Choisis le certificat **Apple Distribution** créé à l'étape 3.
5. Nom du profil : `Mini Planete AppStore` → *Generate* → télécharge le
   `.mobileprovision` dans `~/apple-signing/`.

- Son contenu base64 → secret **`IOS_PROVISIONING_PROFILE_BASE64`**

> Le profil expire en même temps que le certificat (1 an). Il faudra alors
> refaire les étapes 3 et 4 et mettre à jour les 3 secrets correspondants.

## Étape 5 — Créer la fiche de l'app dans App Store Connect

L'envoi TestFlight exige que l'app existe déjà :

1. <https://appstoreconnect.apple.com/apps> → **+** → *Nouvelle app*.
2. Plateforme **iOS**, nom `Mini Planète` (doit être unique sur l'App Store ;
   sinon `Mini Planète – Civilisation`), langue principale **Français**,
   Bundle ID : celui de l'étape 2, SKU : `miniplanete001`, accès complet.

## Étape 6 — Clé API App Store Connect

Elle permet à fastlane de parler à Apple sans ton mot de passe ni la double
authentification.

1. <https://appstoreconnect.apple.com/access/integrations/api> (*Utilisateurs et
   accès* → *Intégrations* → *App Store Connect API*). La première fois, clique
   sur *Demander l'accès* (validation immédiate pour le titulaire du compte).
2. **Générer une clé API** : nom `GitHub CI`, accès **App Manager** → *Générer*.
3. Note :
   - l'**ID de la clé** (ex. `2X9R4HXF34`) → secret **`ASC_KEY_ID`**
   - l'**Issuer ID** affiché en haut de la page (UUID) → secret **`ASC_ISSUER_ID`**
4. **Télécharge le fichier `AuthKey_XXXX.p8`** — Apple ne le propose **qu'une
   seule fois**. Son contenu base64 → secret **`ASC_KEY_P8_BASE64`**.

## Étape 7 — Encoder les fichiers en base64

GitHub Secrets ne stocke que du texte. Encode chaque fichier **sur une seule ligne** :

**Linux / Git Bash :**
```bash
cd ~/apple-signing
base64 -w0 distribution.p12        > p12.b64.txt
base64 -w0 *.mobileprovision       > profile.b64.txt
base64 -w0 AuthKey_*.p8            > p8.b64.txt
```
(Sur macOS ce serait `base64 -i fichier`, mais tu n'en as pas besoin.)

**PowerShell (Windows) :**
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("distribution.p12")) | Set-Content p12.b64.txt
```

Ouvre chaque `.txt` et copie tout son contenu.

## Étape 8 — Créer les secrets GitHub

Dépôt GitHub → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**. Crée exactement ces 8 secrets :

| Secret | Contenu | Étape |
|---|---|---|
| `APPLE_TEAM_ID` | Team ID (10 caractères) | 1 |
| `APP_BUNDLE_ID` | ex. `com.tonnom.miniplanete` | 2 |
| `IOS_DIST_CERT_P12_BASE64` | contenu de `p12.b64.txt` | 3 + 7 |
| `IOS_DIST_CERT_PASSWORD` | mot de passe du `.p12` | 3 |
| `IOS_PROVISIONING_PROFILE_BASE64` | contenu de `profile.b64.txt` | 4 + 7 |
| `ASC_KEY_ID` | ID de la clé API | 6 |
| `ASC_ISSUER_ID` | Issuer ID (UUID) | 6 |
| `ASC_KEY_P8_BASE64` | contenu de `p8.b64.txt` | 6 + 7 |

Ensuite, **supprime les fichiers `.b64.txt`** et garde `~/apple-signing/` en lieu
sûr (sauvegarde chiffrée) : tu en auras besoin au renouvellement annuel.

## Étape 9 — Lancer un build TestFlight

Au choix :
- **Manuel** : onglet **Actions** → *iOS → TestFlight* → **Run workflow**.
- **Par tag** : `git tag v0.1.0 && git push origin v0.1.0`.

Le build prend ~15–25 min. Le **numéro de build** est calculé automatiquement
(dernier build TestFlight + 1). La **version** affichée vient du fichier `VERSION`.

Puis, ~10–30 min plus tard (traitement Apple) :
1. App Store Connect → ton app → **TestFlight**.
2. Ajoute‑toi comme testeur interne (*Testeurs internes* → **+**).
3. Installe l'app **TestFlight** sur ton iPhone et accepte l'invitation.

## Dépannage

| Symptôme | Cause probable |
|---|---|
| `Missing secret …` | secret absent ou mal nommé (sensible à la casse) |
| `Could not find App with bundle identifier` | étape 5 non faite ou Bundle ID différent |
| `MAC verification failed` / import du `.p12` | mauvais mot de passe, ou `.p12` créé sans `-legacy` |
| `No signing certificate "iOS Distribution" found` / profil ne correspond pas | le profil n'a pas été généré avec CE certificat : refais l'étape 4 |
| `Authentication credentials are missing or invalid` | `ASC_KEY_ID`, `ASC_ISSUER_ID` ou `.p8` incorrects |
| Erreur d'export Godot (templates) | la version `GODOT_VERSION` des workflows n'existe pas : mets la dernière stable |
| `The bundle version must be higher` | un build avec ce numéro existe déjà : relance simplement |

## Changer de version de Godot

Une seule valeur à modifier : `GODOT_VERSION` en tête des deux fichiers dans
`.github/workflows/`. Les caches sont automatiquement invalidés.
