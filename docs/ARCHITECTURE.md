# OptiFin — Architecture

## Arborescence

```
Optifin/                              ← application Flutter (racine du dépôt)
├── pubspec.yaml
├── analysis_options.yaml
├── docs/
│   ├── ARCHITECTURE.md               ← ce fichier
│   ├── DESIGN_SYSTEM.md
│   ├── DECISIONS.md                  ← journal des décisions (ADR courts)
│   └── PLAYBACK_TEST_MATRIX.md       ← (phase 4) matrice fichiers × moteur
│
├── packages/
│   ├── jellyfin_api/                 ← client API GÉNÉRÉ (ne pas éditer à la main)
│   │   ├── openapi/jellyfin-openapi-stable.json   ← spec officielle vendorisée
│   │   ├── swagger_parser.yaml       ← config de génération (tags retenus)
│   │   └── lib/src/generated/…       ← clients Retrofit + modèles json_serializable
│   │
│   └── optifin_native_player/        ← PLUGIN NATIF MAISON (platform channels)
│       ├── lib/                      ← API Dart du plugin (MethodChannel/EventChannel, PlatformView)
│       ├── ios/Classes/              ← Swift : AVPlayer + AVPlayerLayer (UiKitView), PiP, AirPlay
│       └── android/src/main/kotlin/  ← Kotlin : Media3/ExoPlayer + SurfaceView (AndroidView), PiP
│
├── lib/
│   ├── main.dart / bootstrap.dart    ← init minimale (pas de libmpv ici !)
│   ├── app/                          ← MaterialApp, go_router, shell de navigation
│   ├── core/
│   │   ├── design_system/            ← tokens, thème, composants partagés
│   │   ├── network/                  ← Dio, intercepteur d'auth Jellyfin, URL d'images
│   │   ├── storage/                  ← Drift (SQLite), secure storage
│   │   └── platform/                 ← infos appareil, identifiant device stable
│   └── features/
│       ├── auth/                     ← serveurs, découverte UDP, login, Quick Connect, multi-comptes
│       ├── home/ library/ details/ search/
│       ├── player/
│       │   ├── domain/
│       │   │   ├── playback_engine.dart     ← INTERFACE UNIQUE vue par l'UI
│       │   │   ├── engine_capabilities.dart
│       │   │   ├── engine_selector.dart     ← décision Natif / mpv / Transcode (pur Dart, testé)
│       │   │   └── device_capabilities.dart
│       │   ├── data/engines/
│       │   │   ├── mpv_engine.dart          ← MOTEUR 1 : libmpv via media_kit (chargé à la demande)
│       │   │   └── native_engine.dart       ← MOTEUR 2 : adaptateur vers optifin_native_player
│       │   └── presentation/                ← UI du lecteur, agnostique du moteur
│       ├── music/ downloads/ live_tv/ syncplay/ remote/ settings/
│       └── …
└── test/                             ← miroir de lib/ (unit + widget)
```

Chaque feature suit `data / domain / presentation` :
- **domain** : entités et règles, Dart pur, sans Flutter ni Dio → 100 % testable.
- **data** : repositories, accès API/DB, mapping DTO → entités.
- **presentation** : widgets + providers Riverpod (état d'écran).

## Flux de lecture (cible phases 3-4)

```
Fiche ouverte ──► PlaybackInfo (préchargé) ──► EngineSelector.decide(mediaSource, deviceCaps, prefs)
                                                    │
                    ┌───────────────────────────────┼─────────────────────────────┐
                 Native (AVPlayer/Media3)       Mpv (media_kit)            Transcode serveur
                    └───────────────┬───────────────┴──────────────┬──────────────┘
                              PlaybackEngine (interface)     fallback auto si échec au démarrage
                                    │
                              PlayerScreen (UI unique)
```

## Choix techniques et écarts assumés

| Sujet | Choix | Pourquoi |
|---|---|---|
| Génération du client API | `swagger_parser` (pur Dart) → Retrofit + json_serializable, **filtré par tags** | openapi-generator exige Java et produit ~1 000 fichiers built_value très lents à compiler. Filtrer les tags garde le code utile seulement. |
| Riverpod | Riverpod 3 **sans** riverpod_generator | Moins de build_runner, providers explicites et lisibles. |
| libmpv | `MediaKit.ensureInitialized()` appelé au 1er usage du moteur mpv | Exigence « chargé à la demande » ; démarrage à froid non pénalisé. |
| Rendu natif Android | `AndroidView` (Hybrid Composition forcée quand SurfaceView) | SurfaceView requis pour HDR + PiP ; coût de composition accepté pendant la lecture uniquement. |
| iOS | Non compilable sur cette machine (Windows) | Le code Swift est écrit ; build/test à faire sur macOS. |
