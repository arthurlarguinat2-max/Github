# Compiler BCD sur son Mac

`bcd-local-build.py` exécute la recette officielle de BCD (`.github/workflows/build-ipa.yml` de
[thebcd69/bcd-games](https://github.com/thebcd69/bcd-games), GPL-3.0) sur ton Mac, étape par étape,
comme le ferait un serveur de GitHub. Les ~650 étapes de test (« Check … ») et celles qui demandent
les clés privées du développeur (signature, envoi en ligne) sont sautées : il reste environ 220 étapes.

## Avant de commencer
- Mac avec puce Apple, Xcode 27 et le SDK iOS, environ **100 Go libres**, branché, sans mise en veille.
- Outils :
  ```
  brew install bison llvm lld ninja meson cabextract msitools python git ccache pyyaml
  ```

## 1. Le code de BCD 0.1.721 (la version de l'iPhone)
```
mkdir -p ~/bcd-lab && cd ~/bcd-lab
git clone https://github.com/thebcd69/bcd-games.git bcd-full
cd bcd-full
git checkout 8c784fe01359ece82158567676948628f5f41099
git submodule update --init --recursive
```

## 2. Le script
```
curl -fLO https://raw.githubusercontent.com/arthurlarguinat2-max/Github/claude/fervent-allen-7jcrq9/ci/bcd-local-build/bcd-local-build.py
python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full --list      # voir les étapes
python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full             # compiler
```

## 3. Si une étape échoue
Le script s'arrête, affiche les dernières lignes et le chemin du log
(`~/bcd-lab/bcd-full/.local-build/logs/NNN.log`). Envoie ce log à Claude, corrige, puis relance :
```
python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full --from NNN
```
Les étapes déjà réussies ne sont pas refaites.

## 4. Le résultat
L'IPA non signée est dans `~/bcd-lab/bcd-full/build-out/`. Envoie-la sur l'iPhone (AirDrop,
iCloud Drive) et installe-la **avec SideStore** (« Keep App Extensions (Use Main Profile) »).
