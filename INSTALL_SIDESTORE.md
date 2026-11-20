# Mini Planète gratuite, mises à jour depuis l'iPhone (SideStore)

**Le principe :**
- tu installes **SideStore** sur l'iPhone **une seule fois** avec le Mac ;
- ensuite, tout se fait depuis l'iPhone : chaque nouvelle version du jeu
  apparaît dans SideStore avec un bouton **Mettre à jour** ;
- SideStore renouvelle l'app tous les 7 jours, la règle des comptes Apple
  gratuits.

> SideStore est une app gratuite et open source, mais **non officielle**
> (pas faite par Apple). Elle utilise ton identifiant Apple uniquement pour
> signer les apps.

---

## Partie A — Avec le Mac (une seule fois, ~30 min)

### A1. Libérer de la place sur l'iPhone
Un compte Apple gratuit n'autorise que **3 apps** installées de cette façon,
**SideStore compris**. SideStore + Mini Planète = 2 places : il faut donc
qu'il en reste au plus **1** parmi Glass Home Remote, Le Musée Unreal et
Musée Auto. Supprime les autres de l'iPhone (appui long → Supprimer l'app).

### A2. Installer LocalDevVPN sur l'iPhone
App Store → cherche **LocalDevVPN** → installe‑la.
C'est un « VPN » local (rien ne sort de ton téléphone) qui permet à SideStore
d'installer et renouveler les apps sans ordinateur.

### A3. Installer iloader sur le Mac
**iloader** est l'installateur officiel recommandé par SideStore.
1. Sur le Mac : <https://github.com/nab138/iloader/releases/latest> →
   télécharge le fichier **`.dmg`** pour macOS.
2. Ouvre‑le, glisse **iloader** dans **Applications**.
3. Si macOS le bloque : Réglages Système → **Confidentialité et sécurité** →
   **Ouvrir quand même** (comme pour Sideloadly).

### A4. Installer SideStore
1. Branche l'iPhone au Mac, déverrouille‑le, touche **Se fier**.
2. Ouvre **iloader** → connecte‑toi avec ton **identifiant Apple**
   (+ code à 6 chiffres).
3. Choisis ton iPhone, puis **Install SideStore**. Attends le message de
   réussite.
4. Si iloader propose de placer le **fichier de jumelage** (*Pairing File* →
   **Place** à côté de SideStore), fais‑le : c'est ce qui permet à SideStore
   de fonctionner sans le Mac.

### A5. Autoriser sur l'iPhone
- Réglages → **Confidentialité et sécurité** → **Mode développeur** :
  activé (si ce n'est pas déjà fait).
- Réglages → **Général** → **VPN et gestion de l'appareil** → ton
  identifiant Apple → **Faire confiance**.

### A6. Premier test (Mac encore branché)
1. Ouvre **LocalDevVPN** → **Connect**.
2. Ouvre **SideStore** → connecte‑toi avec ton identifiant Apple si demandé.
3. Onglet **My Apps** → **Refresh All**. Si ça marche, **le Mac n'est plus
   nécessaire**. 🎉

---

## Partie B — Depuis l'iPhone uniquement

### B1. Ajouter la source Mini Planète (une fois)
SideStore → onglet **Sources** → **+** → colle cette adresse :

```
https://github.com/arthurlarguinat2-max/Github/releases/latest/download/source.json
```

→ **Add Source**.

### B2. Installer le jeu
SideStore → **Browse** → **Mini Planète** → **Free** / **Get** (avec
LocalDevVPN connecté et en Wi‑Fi).

### B3. Mettre à jour
Quand j'ai publié une nouvelle version (je te le dis dans le chat) :
SideStore → **My Apps** → **Mini Planète** → **Update**.
Ta partie est conservée.

### B4. Tous les 7 jours
Ouvre **LocalDevVPN** (Connect) puis **SideStore** → **My Apps** →
**Refresh All**. SideStore t'indique le nombre de jours restants.

**Automatique (conseillé) :** app **Raccourcis** → **Automatisation** →
**+** → *Heure de la journée*, chaque jour, **Exécuter immédiatement** →
action **SideStore › Refresh All**. Laisse LocalDevVPN connecté en Wi‑Fi.

---

## Si la source ne marche pas : installation manuelle
1. Safari → <https://github.com/arthurlarguinat2-max/Github/releases/latest>
   → touche **MiniPlanete.ipa** → **Télécharger**.
2. SideStore → **My Apps** → **+** → *Téléchargements* → `MiniPlanete.ipa`.

## Dépannage

| Problème | Solution |
|---|---|
| Erreur de connexion / « Could not connect » | LocalDevVPN connecté ? Wi‑Fi activé ? (le Wi‑Fi est obligatoire) |
| Erreurs de « pairing » persistantes | Il faut refaire le fichier de jumelage avec iloader (Mac nécessaire) |
| « Maximum number of apps » | Limite de 3 apps : supprime une app installée par SideStore |
| L'app ne s'ouvre plus | Elle a expiré : B4 |
| Une version GitHub est rouge | Préviens Claude : il lit les logs et corrige |

**Garde le Mac accessible de temps en temps** : en cas de gros souci (mise à
jour d'iOS, fichier de jumelage invalide), il peut redevenir nécessaire.
