# Installer et mettre à jour le jeu sur l'iPhone (AltStore)

Méthode **gratuite** (identifiant Apple gratuit). Le jeu est fabriqué par
GitHub ; AltStore l'installe et le renouvelle.

## La configuration actuelle (déjà faite)
- **AltStore Classic 2.3.3** installé sur l'iPhone, connecté à ton identifiant
  Apple (compte « Free Developer Account »).
- **Remote AltServer** activé dans AltStore → Settings, serveur **StikStore** :
  permet d'installer et de renouveler **sans le Mac**.
- **LocalDevVPN** installé (nécessaire au mode sans Mac).
- **AltServer** installé sur le Mac (solution de secours).

## Mettre à jour le jeu (à chaque nouvelle version)
1. Attends la ✅ dans GitHub → Actions (voir `02_MODIFIER_VIA_GITHUB.md`).
2. Sur l'iPhone : **Wi‑Fi activé** + ouvre **LocalDevVPN** → **Connect**.
3. **AltStore** → **My Apps** → tire l'écran vers le bas pour actualiser →
   **Update** à côté de Mini Planète.
4. Au lancement, le jeu affiche « Version x.y.z installée ». Ta partie est
   conservée.

Si « Update » n'apparaît pas : AltStore → **Sources** → tire vers le bas pour
actualiser la source Mini Planète, puis retourne dans **My Apps**.

## La règle des 7 jours (comptes Apple gratuits)
- Une app installée ainsi **expire au bout de 7 jours** (elle ne s'ouvre plus).
- Toutes les 4‑5 jours : **Wi‑Fi + LocalDevVPN** → AltStore → **My Apps** →
  **Refresh All**. Ça renouvelle Mini Planète **et AltStore lui‑même**.
- Une mise à jour remet aussi le compteur à 7 jours.
- **Ne supprime jamais l'app expirée** : ta partie est dedans. Renouvelle‑la.

## Wi‑Fi ou 5G ?
- Installer / mettre à jour / renouveler demande en général un **Wi‑Fi**
  (n'importe lequel) avec LocalDevVPN connecté. Essaie aussi « Wi‑Fi activé
  mais non connecté » en 5G : ça marche sur certains iPhone.
- Le partage de connexion **d'un autre téléphone** compte comme un Wi‑Fi.
- **Jouer** ne demande ni Wi‑Fi ni 5G.

## Limite de 3 apps
Un compte Apple gratuit permet **3 apps** installées de cette façon,
AltStore compris. AltStore + Mini Planète = 2 places.

## Si quelque chose ne marche plus
| Problème | Solution |
|---|---|
| Erreur de connexion / « Could not connect » | Wi‑Fi activé ? LocalDevVPN connecté ? Réessaie. |
| Remote AltServer ne marche plus | Rallume le **Mac**, ouvre **AltServer** (icône ◇ en haut à droite), même Wi‑Fi que l'iPhone, puis Refresh All. |
| AltStore lui‑même a expiré (ne s'ouvre plus) | Sur le Mac : iPhone branché → icône ◇ → **Install AltStore** → ton iPhone. Puis Refresh All. Ta partie reste. |
| « Maximum number of apps » | Supprime une autre app installée par AltStore. |
| Erreur 503 / connexion Apple refusée | Attends quelques heures (Apple bloque après trop d'essais), un seul essai ensuite. |

## Installer à la main (secours)
1. Safari → <https://github.com/arthurlarguinat2-max/Github/releases/latest> →
   télécharge **MiniPlanete.ipa**.
2. AltStore → **My Apps** → **+** → choisis le fichier dans Téléchargements.
   (Ou sur le Mac : **iloader** → Import IPA, ou **Sideloadly**.)

## Option payante (plus aucun souci de 7 jours ni de Mac)
Compte Apple Developer (99 $/an) + **TestFlight** : tout est déjà prêt dans le
dépôt (`BUILD.md`, workflow `ios-testflight.yml`, 6 secrets à créer).
