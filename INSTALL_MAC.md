# Installer Mini Planète gratuitement avec un Mac

Pas de compte Apple Developer payant : GitHub fabrique l'app, ton Mac
l'installe sur ton iPhone avec **Sideloadly** et ton **identifiant Apple
gratuit**. L'app reste privée, sur ton téléphone uniquement.

> **La règle d'Apple pour les comptes gratuits :** l'app expire au bout de
> **7 jours** (elle ne s'ouvre plus). Il suffit de la réinstaller depuis le Mac
> (2 min), ou d'activer le renouvellement automatique (étape 6).
> Ta partie est conservée tant que tu ne supprimes pas l'app.

---

## Étape 1 — Fabriquer l'app sur GitHub (depuis le Mac ou l'iPhone)

1. Ouvre ton dépôt sur github.com → onglet **Actions**.
2. Dans la liste de gauche : **iOS – IPA gratuit (Sideloadly)**.
3. **Run workflow** → choisis la branche `claude/mini-planete-ios-godot-9vnfsb`
   → **Run workflow**.
4. Attends la coche verte (~10–20 min).
5. Clique sur l'exécution → en bas, section **Artifacts** → **MiniPlanete-ipa**
   → le fichier `.zip` se télécharge sur le Mac.
6. Double‑clique sur le `.zip` : tu obtiens `MiniPlanete-x.y.z-N.ipa`.

## Étape 2 — Installer Sideloadly sur le Mac

1. Va sur <https://sideloadly.io> → télécharge la version **macOS**.
2. Ouvre le `.dmg` → glisse Sideloadly dans **Applications**.
3. Premier lancement : si macOS bloque l'ouverture, va dans
   **Réglages Système → Confidentialité et sécurité** → **Ouvrir quand même**.

## Étape 3 — Brancher l'iPhone

1. Branche l'iPhone au Mac avec un câble.
2. Sur l'iPhone, touche **Se fier à cet ordinateur** et entre ton code.

## Étape 4 — Installer l'app

1. Dans Sideloadly :
   - **iDevice** : ton iPhone doit apparaître ;
   - **Apple account** : ton identifiant Apple habituel ;
   - glisse le fichier `.ipa` sur l'icône **IPA** de la fenêtre.
2. Clique **Start**. Entre le mot de passe de ton identifiant Apple, puis le
   **code à 6 chiffres** reçu sur ton iPhone (double authentification).
3. Attends « **Done** ».

Ton mot de passe est envoyé uniquement à Apple, pour signer l'app.
Si tu préfères, crée un identifiant Apple secondaire dédié à ça.

## Étape 5 — Autoriser l'app sur l'iPhone (une seule fois)

1. **Mode développeur** : Réglages → **Confidentialité et sécurité** →
   tout en bas, **Mode développeur** → activer → l'iPhone redémarre →
   confirme **Activer**.
   *(L'option apparaît après la première installation par Sideloadly.)*
2. **Faire confiance** : Réglages → **Général** →
   **VPN et gestion de l'appareil** → ton identifiant Apple → **Faire confiance**.
3. Lance **Mini Planète** depuis l'écran d'accueil. 🌍

## Étape 6 — Tous les 7 jours (ou à chaque nouvelle version)

**À la main (2 min) :** rebranche l'iPhone → Sideloadly → même `.ipa` (ou la
nouvelle version de l'étape 1) → **Start**. Ne supprime pas l'app avant :
l'installation par‑dessus conserve ta partie.

**Automatiquement :**
1. Finder → ton iPhone (iPhone branché) → coche **Afficher cet iPhone en
   Wi‑Fi** → **Appliquer**.
2. Dans Sideloadly, avant **Start** : **Advanced options** → coche
   **Enable automatic refresh**.
3. Laisse Sideloadly ouvert sur le Mac : il renouvelle l'app tout seul quand
   l'iPhone et le Mac sont sur le même Wi‑Fi.

---

## Dépannage

| Problème | Solution |
|---|---|
| L'iPhone n'apparaît pas dans Sideloadly | Débranche/rebranche, déverrouille l'iPhone, retouche « Se fier » ; essaie un autre câble |
| « Your maximum App ID limit has been reached » | Limite Apple des comptes gratuits (10 par semaine) : attends quelques jours, garde toujours le même `.ipa` |
| « Untrusted Developer » / l'app ne s'ouvre pas | Étape 5 |
| L'app s'ouvre puis se ferme au bout d'une semaine | Elle a expiré : étape 6 |
| Le workflow GitHub est rouge | Préviens Claude : il lit les logs et corrige |

## Plus tard : sans câble, sans renouvellement

Le compte Apple Developer (99 $/an) permet de passer par **TestFlight** :
mises à jour depuis l'iPhone, validité de 90 jours, plus besoin du Mac.
Tout est déjà prêt, voir [BUILD.md](BUILD.md).
