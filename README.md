# OptiFin

Client Jellyfin premium pour iOS et Android (Flutter) : interface immersive façon Infuse,
moteur de lecture hybride natif (AVPlayer / Media3) + libmpv.

- Architecture : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Design system : [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md)
- Décisions : [docs/DECISIONS.md](docs/DECISIONS.md)

## Développement

```bash
flutter pub get
dart run build_runner build -d   # Drift
flutter analyze && flutter test
```

Régénérer le client API (après mise à jour de la spec) :

```bash
cd packages/jellyfin_api
dart run tool/prepare_spec.dart && dart run swagger_parser && dart run build_runner build -d
```

## Installer / mettre à jour avec SideStore

Ajoutez cette source dans SideStore (onglet Sources › +) :

```
https://github.com/AL1X0/OptiFin/releases/latest/download/source.json
```

Chaque push sur `main` publie une nouvelle build (Release GitHub `build-N`) : SideStore la
propose en mise à jour. Le bundle ID reste `app.optifin.optifin`.

## CI

`.github/workflows/ci.yml` : analyse + tests, APK Android, **IPA iOS non signée**
(artefact `optifin-ios-unsigned`, à signer via Sideloadly/AltStore ou avec un certificat Apple).
