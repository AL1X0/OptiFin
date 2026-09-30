<div align="center">

<img src="assets/branding/icon_1024.png" width="104" alt="Logo OptiFin" />

# OptiFin

**Votre Jellyfin, en version cinéma.**

Client [Jellyfin](https://jellyfin.org) pour iPhone, iPad, Android, Android TV et Windows.

[![CI](https://github.com/AL1X0/OptiFin/actions/workflows/ci.yml/badge.svg)](https://github.com/AL1X0/OptiFin/actions/workflows/ci.yml)
[![Dernière build](https://img.shields.io/github/v/release/AL1X0/OptiFin?label=build&color=4DA3FF)](https://github.com/AL1X0/OptiFin/releases/latest)
![Plateformes](https://img.shields.io/badge/iOS%2015%2B%20·%20Android%207%2B%20·%20Windows%2010%2B-111?logo=flutter)

<a href="https://github.com/AL1X0/OptiFin/blob/main/docs/media/optifin-demo.mp4">
  <img src="docs/media/optifin-demo.jpg" width="820" alt="Vidéo de présentation d'OptiFin" />
</a>

▶ [**Regarder la vidéo**](https://github.com/AL1X0/OptiFin/blob/main/docs/media/optifin-demo.mp4) · 30 s, avec le son

<img src="docs/media/appstore.jpg" width="900" alt="Accueil, fiche, séries, lecteur et téléchargements" />

</div>

## En bref

- **Une interface immersive** : carrousel à la une, fiches avec logos et badges 4K · Dolby Vision · Atmos, verre « Liquid Glass ».
- **Un lecteur hybride** : AVPlayer, Media3 ou mpv choisi automatiquement pour chaque fichier, sans transcodage inutile.
- **Pensé pour les séries** : reprise synchronisée, « Passer l'intro », épisode suivant préparé pendant le générique.
- **Hors connexion** : films et saisons téléchargés en arrière-plan, lus sans réseau.
- **iPhone, iPad, Android, Android TV** (télécommande) **et Windows** (souris, clavier, vrai HDR), Picture-in-Picture, AirPlay.

## Installer

**iPhone / iPad (SideStore)** : ajoutez cette source dans SideStore (Sources › +) ; chaque nouvelle version y est proposée.

```
https://raw.githubusercontent.com/AL1X0/OptiFin/sidestore/source.json
```

**Android et Android TV** : `OptiFin-android-arm64-v8a.apk` (ou `armeabi-v7a` pour les box et Fire TV plus anciens) dans la [dernière Release](https://github.com/AL1X0/OptiFin/releases/latest).

**Windows 10 / 11** : `OptiFin-windows-setup.exe` dans la [dernière Release](https://github.com/AL1X0/OptiFin/releases/latest). Installation sans droits administrateur ; l'appli se met ensuite à jour toute seule.

Serveur Jellyfin 10.9 ou plus récent.

## Développement

```bash
flutter pub get && flutter analyze && flutter test
```

Vidéo et captures App Store (`docs/appstore/`, 1320 × 2868) : `bash demo/make_demo.sh`.
Windows (Visual Studio 2022 C++ avec ATL, Inno Setup 6) : `powershell -File windows\installer\build.ps1`.
Documentation : [architecture](docs/ARCHITECTURE.md) · [décisions](docs/DECISIONS.md) · [matrice des moteurs](docs/TEST_MATRIX.md).
