# Journal des décisions

## Phase 1 — Fondations (2026-09-27)

1. **Client API : swagger_parser plutôt qu'openapi-generator.** Pur Dart (pas de Java),
   sortie Retrofit + json_serializable, filtrée par tags (33 clients / ~300 modèles au lieu de
   l'API admin complète). La spec officielle (`jellyfin-openapi-stable.json`, Jellyfin 12.1)
   est vendorisée ; `tool/prepare_spec.dart` corrige deux défauts du générateur
   (défauts d'enum émis en identifiants nus, corps binaires optionnels).
2. **Compatibilité serveur : 10.9 minimum**, vérifiée à la connexion. Les endpoints utilisés
   (`/Items`, `/UserViews`, `/QuickConnect/*`, `/Users/AuthenticateByName`) sont stables depuis 10.9.
3. **Riverpod 3 sans riverpod_generator** : providers explicites, moins de codegen.
4. **Tokens** uniquement dans le trousseau/Keystore (`TokenVault`), jamais en base ni dans les logs.
   Pas de `LogInterceptor` Dio (les en-têtes contiennent le token).
5. **Démarrage** : bootstrap 100 % local (Drift + trousseau), aucun appel réseau ; la session
   est restaurée avant le premier frame.
6. **Découverte réseau** : UDP 7359. Sur iOS, le broadcast exige l'entitlement
   `com.apple.developer.networking.multicast` (demande à Apple) ; sans lui la découverte
   renvoie une liste vide et la saisie manuelle reste disponible.
7. **ATS / cleartext autorisés** : beaucoup de serveurs Jellyfin sont en HTTP sur le LAN.
8. **media_kit / just_audio** ne sont pas encore dépendances : ajoutés en phases 3 et 6 pour
   ne pas alourdir le build tant qu'ils ne servent pas.

## Phase 2 — Navigation (2026-09-27)

1. **Modèle de domaine `MediaItem`** (lib/core/media) : les écrans ne voient jamais les DTO
   générés. Le mapping choisit les images de repli (épisode → affiche/backdrop/logo de la série).
2. **Tolérance serveur** : `prepare_spec.dart` rend nullables tous les champs des modèles
   (sauf `Id`). Sans ça, un champ récent absent d'un serveur plus ancien (ex. `HasSegments`)
   faisait échouer le parsing de toute la réponse. Test de non-régression dédié.
3. **Accueil depuis le cache** : l'accueil brut (DTO) est stocké dans Drift (`CachedResponses`)
   et affiché immédiatement au démarrage, puis remplacé par la version réseau. Hors ligne,
   l'accueil en cache reste affiché. Purgé à la déconnexion du compte.
4. **Bibliothèques à accès aléatoire** (`LibraryPager`) : pages de 100 chargées à la demande
   par la grille, LRU de 12 pages. L'index alphabétique calcule la position d'une lettre
   côté serveur (`nameLessThan` + `limit=0`) puis saute directement : pas besoin de charger
   ce qui précède, même sur 20 000 films.
5. **Tri aléatoire retiré des bibliothèques** : le serveur retire au sort à chaque page,
   ce qui produit doublons/trous en pagination.
6. **Filtre HDR non proposé** : `/Items` n'expose aucun filtre de plage dynamique ; il faudrait
   filtrer côté client, incompatible avec la pagination. Résolution (HD/4K) disponible.
7. **Hero** : le tag inclut la rangée source (`home-resume:<id>`) car un même titre peut
   apparaître dans plusieurs rangées d'une page. Transmis à la fiche via `extra`.
   Téléphone : la carte « zoome » vers le backdrop ; tablette : vers l'affiche.
8. **Accent dynamique** : image décodée à 24 px, histogramme de teintes pondéré par la
   saturation (la moyenne donne des couleurs boueuses), normalisé pour rester lisible.
9. **Navigation** : 3 onglets (`StatefulShellRoute`), les fiches s'ouvrent dans l'onglet
   courant (état de chaque onglet conservé). Rail latéral à partir de 840 px.
10. **Bouton Lecture** présent mais informe que le lecteur arrive en phase 3.
    `PlaybackInfo` préchargé à l'ouverture de la fiche : phase 3 (dépend du moteur).

## Distribution

- **Bundle ID figé : `app.optifin.optifin`** (iOS et Android). L'IPA non signée de chaque
  version peut être re-signée indéfiniment avec le même profil et s'installe par-dessus la
  précédente. La CI échoue si l'identifiant change (projet Xcode, Gradle, et Info.plist de
  l'app construite).
- **Numéro de build = numéro d'exécution CI** (`--build-number`), croissant à chaque push :
  chaque version est reconnue comme une mise à jour.

## Phase 3 — Moteur de lecture (socle) (2026-09-28)

1. **Interface `PlaybackEngine`** (lib/features/player/domain) : commandes, flux d'états
   (`PlayerSnapshot`), événements, capacités déclarées (`EngineCapabilities`), surface vidéo.
   L'UI du lecteur ne connaît que ce contrat.
2. **Pistes : index Jellyfin → ordinal moteur.** Le serveur identifie une piste par son index
   global de flux ; les moteurs par sa position parmi les pistes du même type. `embeddedOrdinal`
   fait la conversion (les sous-titres externes n'ont pas d'ordinal : chargés par URL).
3. **Changement de piste** : instantané en Direct Play ; en Direct Stream / transcodage le serveur
   n'envoie que la piste choisie → nouveau `PlaybackInfo` et rechargement à la position courante.
   Sous-titre image pendant un transcodage → incrustation serveur (rechargement).
4. **libmpv** : chargé au premier lancement d'une lecture (`MpvEngine.create`), décodage matériel
   `auto-safe`, sous-titres rendus par libass dans l'image (styles ASS et PGS fidèles).
   Android : libass pointé sur `/system/fonts` (pas de fontconfig), sinon texte invisible.
5. **Token jamais dans l'URL du flux** : envoyé en en-tête `Authorization` à mpv.
6. **`PlaybackInfo` préchargé** à l'ouverture de la fiche (conservé 2 min) : l'appui sur Lecture
   ne fait plus que créer le moteur et ouvrir le flux.
7. **Reporting** : start, progress toutes les 10 s + à chaque pause/reprise/seek, stopped avec la
   dernière position. Erreurs réseau ignorées (la lecture continue).
8. **Retry Riverpod** : la politique par défaut de Riverpod 3 (10 tentatives) masquait les erreurs
   définitives (refus de lecture) derrière un chargement. Désormais : erreurs réseau
   transitoires seulement, 2 tentatives (`networkRetry`).
9. **Gestes** : double-tap ±10 s ; la couche de gestes est sous les contrôles pour que les boutons
   répondent sans le délai de 300 ms du double-tap. Luminosité/volume, verrouillage : phase 5.
10. **À vérifier sur appareil** : décodage matériel 4K HEVC, polices libass Android, HDR (mpv fait
    du tone-mapping ; le HDR natif relève des moteurs natifs de la phase 4).

## Correctifs et outillage (2026-09-28)

1. **Lecture en échec systématique** : le client généré envoyait tous les champs `null`
   (ex. `TranscodingProfile.TranscodeSeekInfo`) ; le serveur .NET refuse `null` sur ses
   propriétés non-nullables → 400 sur `PlaybackInfo`. `build.yaml` du client :
   `include_if_null: false`. Test de régression : aucun `null` dans les corps envoyés.
2. **Journal** (`AppLog`) : tampon circulaire de 3000 lignes, secrets masqués à l'écriture
   (token, ApiKey, mots de passe). Alimenté par Dio (statut, durée, début de réponse en cas
   d'erreur), le lecteur (plan, URL, pistes), mpv (mode debug), les erreurs Flutter.
   Paramètres › Journaux : filtre, copie, effacement.
3. **Paramètres** stockés en base (clé `settings`, JSON tolérant aux versions) : débit max
   Wi-Fi / cellulaire (connectivity_plus), langues audio / sous-titres, mode des sous-titres,
   style des sous-titres, mode debug. Préférences de langue appliquées localement en Direct
   Play, via un nouveau `PlaybackInfo` sinon.
4. **Icône** : logo ruban « play » noir et blanc ; icône adaptative Android (fond noir,
   premier plan blanc à alpha = luminance), écran de démarrage noir.
5. **Source SideStore** : Release GitHub par build (`build-N`, 10 dernières conservées) avec
   l'IPA et `source.json` ; URL stable `releases/latest/download/source.json`.

## Phase 4 — Moteurs natifs et EngineSelector (2026-09-28)

1. **Plugin `optifin_native_player`** : AVPlayer + `AVPlayerLayer` en `UiKitView` (iOS),
   Media3/ExoPlayer + `PlayerView` (SurfaceView) en composition hybride (Android). API Dart
   minimale (MethodChannel par lecteur, EventChannel d'états toutes les 250 ms). Les gestes
   restent à Flutter. Pas d'extension FFmpeg Media3 (non publiée sur Maven) : DTS / TrueHD sans
   décodeur → mpv, ou conversion audio par le serveur quand la vidéo impose le natif.
2. **Détection des capacités** au premier besoin (fiche ou lecture) : décodeurs matériels
   (VideoToolbox / MediaCodec), HEVC 10 bits, AV1, modes HDR de l'écran, profils Dolby Vision,
   codecs audio. Android : HDR seulement si l'écran l'affiche (Media3 ne convertit pas en SDR) ;
   iOS : HDR10/HLG dès que le HEVC 10 bits est décodé (AVPlayer convertit), DV si
   `AVPlayer.availableHDRModes` le permet.
3. **Préparation en deux temps** : `PlaybackInfo` d'analyse avec le profil mpv (qui accepte tout
   en lecture directe) pour la description complète de la source, puis `EngineSelector`, puis
   `PlaybackInfo` définitif avec le profil du moteur choisi. Si c'est mpv en lecture directe,
   l'analyse sert de plan (aucune requête de plus). Le tout dès l'ouverture de la fiche.
4. **Règles de l'EngineSelector** (en-tête de `engine_selector.dart`, `docs/TEST_MATRIX.md`) :
   débit → transcodage ; préférence explicite ; HDR/DV → natif (remux serveur HLS fMP4 si
   conteneur ou audio incompatibles, plutôt que mpv ; exceptions : sous-titres image, ou ASS sur
   du HDR10 → mpv) ; SDR → natif seulement si tout passe tel quel, sinon mpv ; transcodage en
   dernier recours. DV profil 5 sans décodeur DV : transcodage (mpv donnerait des couleurs fausses).
5. **Sous-titres des moteurs natifs** : servis par Jellyfin en WebVTT (profil natif : un seul
   format externe, conversion serveur) et dessinés par OptiFin au-dessus de la vidéo, avec le
   même style que mpv et un décalage réglable. Horloge extrapolée à chaque image : précision à
   la frame malgré des positions reçues toutes les 250 ms. Sous-titres image : mpv (par défaut)
   ou incrustation serveur (Paramètres).
6. **Bascule automatique** : échec avant la première image (erreur moteur, exception à
   l'ouverture, 25 s sans image) → repli suivant de la chaîne (autre moteur, puis transcodage),
   message discret « Bascule vers… ». Le détail de chaque tentative est conservé pour l'écran
   d'erreur (mode debug).
7. **Changement de piste** : l'EngineSelector est relancé ; même moteur et même livraison en
   lecture directe → changement local ; sinon nouveau plan et, si besoin, changement de moteur à
   la position courante (ex. choisir des PGS sur le lecteur natif → mpv).
8. **Réglages** : moteur global (Auto / Natif / mpv) dans les Paramètres, et pour une lecture
   dans la feuille « Audio et sous-titres ». Overlay de debug : décision, raison, mode serveur,
   source, images perdues (mpv : `frame-drop-count`, AVPlayer : access log, Media3 : analytics).
9. **Non vérifiable ici** (Windows, sans Xcode ni SDK Android) : compilation Swift et Kotlin par
   la CI ; comportement réel (HDR, DV) à valider sur appareil (section « Résultats sur appareil »
   de la matrice).

## Source SideStore fiabilisée (2026-09-28)

SideStore a signalé une source « JSON invalide » alors que le fichier était correct : l'adresse
`releases/latest/download/source.json` passe par deux redirections vers un lien signé qui expire,
et renvoie brièvement « Not Found » pendant la publication d'une build. Désormais :
- la source est aussi publiée sur la branche `sidestore` et servie telle quelle par
  `https://raw.githubusercontent.com/AL1X0/OptiFin/sidestore/source.json` (sans redirection) ;
- la Release est créée en brouillon puis publiée une fois l'IPA et la source envoyées.
L'ancienne adresse reste valide.

## Phase 5 — Lecteur avancé (2026-09-28)

1. **Compléments de lecture** (`PlaybackExtrasRepository`), chargés en parallèle du démarrage,
   chacun facultatif (serveur ancien, plugin absent → simplement masqué) : chapitres, manifeste
   trickplay (résolution la plus proche de 320 px), segments média (10.10+), épisode suivant.
2. **Trickplay** : planches JPEG recadrées côté Flutter (une planche = 100 vignettes en cache),
   authentifiées par en-tête. Sans trickplay : heure et chapitre visés. Repères de chapitres
   sur la barre, feuille « Chapitres » avec vignettes.
3. **Segments** : bouton « Passer l'intro / le récap / l'aperçu » visible même contrôles
   masqués ; saut automatique en option (une seule fois par segment, un retour volontaire
   n'est pas contrarié). Le générique est géré par l'épisode suivant quand il y en a un.
4. **Épisode suivant** : carte au début du générique (sinon 30 s avant la fin, jamais avant la
   moitié), compte à rebours de 10 s si « Épisode suivant automatique ». Le plan de l'épisode
   suivant est préparé pendant le générique ; l'enchaînement termine proprement la session
   (rapport stop) et remplace l'écran du lecteur.
5. **Gestes** : glissé vertical gauche = luminosité (de l'app, rétablie en quittant),
   droite = volume système sans le HUD ; verrouillage de l'écran ; cadrage
   contenu → zoom → étiré ; décalages audio (mpv) et sous-titres (tous moteurs) par 0,1 s.
6. **Sous-titres en ligne** : recherche via les fournisseurs du serveur (OpenSubtitles…),
   correspondances exactes d'abord ; téléchargement puis affichage sans interrompre la lecture.
7. **Picture-in-Picture** : iOS via `AVPictureInPictureController` sur la couche du lecteur natif
   (automatique en quittant l'app, mode arrière-plan audio) ; Android sur l'activité entière,
   quel que soit le moteur (auto-entrée Android 12+, `onUserLeaveHint` avant), contrôles
   Flutter masqués pendant le PiP. mpv sur iOS : pas de PiP (pas d'AVPlayerLayer).
8. **AirPlay** : bouton système `AVRoutePickerView` avec le lecteur natif, lecture externe activée.
9. **Chromecast reporté** à la phase 8 (contrôle à distance) : il exige le SDK Google Cast sur les
   deux plateformes et un récepteur ; il sera traité avec les autres « écrans distants ».

## Démarrage natif plus rapide et animations (2026-09-28)

1. **Une seule requête avant la première image** dans le cas courant : l'analyse `PlaybackInfo`
   est faite avec le profil natif ; si le natif est retenu avec le même mode (direct / remux, même
   piste audio), elle sert de plan. mpv en lecture directe réutilise aussi l'analyse (flux
   statique construit localement). Seuls transcodage, incrustation ou autre piste audio en remux
   demandent une seconde requête.
2. **HLS** : un seul segment requis au démarrage, segments de 3 s (au lieu de 2 × 6 s).
3. **AVPlayer** : lecture sans attendre un tampon « confortable » ; reprise sur l'image clé la plus
   proche (≤ 2 s avant) au lieu d'un seek exact. **Media3** : lecture dès 1 s de tampon.
4. **Préchargement** du plan aussi depuis le carrousel de l'accueil (bouton Lecture direct).
5. **Animations** (≤ 300 ms, désactivées avec « Réduire les animations ») : entrées en cascade
   (`FadeSlideIn`, fenêtre d'entrée `EntranceScope` pour ne pas réanimer au défilement),
   fondus enchaînés squelette → contenu (`FadeThroughSwitcher`), onglets en fondu, barre
   d'onglets animée, favori/vu avec rebond, cartes de bibliothèque en diagonale, bouton
   « Passer » et carte « Épisode suivant » glissant depuis la droite.

## Vidéo de démo et médias du README (2026-09-28)

1. **L'app réelle filmée sans appareil** (`demo/`) : `flutter test demo/capture_test.dart` lance
   `OptiFinApp` en rendu iOS, branchée sur un serveur Jellyfin simulé en mémoire (`DemoJellyfinAdapter` :
   les vrais repositories, mappers et l'EngineSelector tournent), et filme chaque scène image par image
   (30 i/s) avec des gestes simulés (doigt visible). Seul le moteur vidéo est remplacé (illustration
   animée à la place d'un flux).
2. **Bibliothèque fictive** : titres, résumés et personnes inventés ; affiches, backdrops, logos et
   portraits **générés par code** (`demo_artwork.dart`) — aucune œuvre ni image externe.
   Hook d'app : `OFImageSource.override` remplace le réseau par ces images (sans effet en production).
3. **Montage** (`demo/stage_test.dart`) : téléphone, textes animés, rotation vers le lecteur, logo, en
   1920×1080 ; **musique synthétisée** (`demo/music.mjs`, nappe en la mineur, clics calés sur les taps).
4. `bash demo/make_demo.sh` régénère la vidéo (`docs/media/optifin-demo.mp4`), les GIF et les captures
   du README. Au passage : note affichée avec une icône étoile (le caractère « ★ » dépend des polices),
   styles de texte hérités dans la barre d'onglets, flux PiP Android plus écouté sur iOS.

## Carrousel sans parallaxe (2026-09-28)

La parallaxe horizontale (image 15 % plus lente que la page) donnait, au relâcher du doigt, l'impression
que l'image « revenait en arrière » en rattrapant la page. Supprimée : l'illustration est solidaire de sa
page (comme Infuse), décodée à la largeur réelle (moins de mémoire). Au swipe, seuls les points se
redessinent (ValueNotifier) au lieu du carrousel entier.

## iPad et lecteur « liquid glass » (2026-09-28)

1. **Tablette** : le rail latéral (noir, plat) est remplacé par une **barre d'onglets flottante en verre**,
   centrée en bas, portrait comme paysage : le contenu garde toute la largeur. Carrousel : titre, boutons et
   points alignés à gauche avec un voile latéral (à la manière de l'Apple TV). Cartes paysage plafonnées à
   264 px (4–5 visibles au lieu de 3 énormes), logos alignés à gauche dans les fiches, synopsis limité à
   820 px de large. Vérifié par des captures iPad 11" (`demo/ipad_audit_test.dart`).
2. **`LiquidGlass`** (design system) : flou partagé (`BackdropGroup`), voile sombre, reflet en dégradé et
   liseré spéculaire. Le voile garde les commandes lisibles là où le flou ne s'applique pas (vue vidéo
   native Android). `OFGlassButton` : bouton rond ou pilule en verre.
3. **Lecteur simplifié** : en haut, seulement fermer, titre, et une pilule AirPlay · PiP · format ·
   **Réglages**. Tout le reste passe dans un **menu en verre à sous-menus** ancré sous son bouton
   (Audio, Sous-titres → recherche en ligne et apparence, Chapitres, Vitesse, Synchronisation, Moteur,
   Verrouiller, Infos techniques), chaque ligne affichant la valeur actuelle. Un choix (piste, vitesse,
   chapitre, moteur) referme le menu ; les réglages fins le gardent ouvert. Le menu ne recouvre jamais la
   barre de progression. Boutons centraux, barre de progression, « Passer l'intro », « Épisode suivant »,
   indicateurs et verrou passent aussi en verre ; tout grandit un peu sur tablette.
4. **Pas de flou au-dessus d'une vue native** : sur iPhone, un flou d'arrière-plan posé sur la vue AVPlayer
   effaçait le contenu des boutons (lecture, barre de progression). `GlassBlur` coupe le flou des verres
   quand le moteur natif lit ; le voile, plus dense, garde l'effet verre. Le flou reste avec mpv (texture).
5. **`OFLoader`** : nouvel indicateur de chargement (arc en dégradé qui tourne et respire), sur pastille de
   verre dans le lecteur (préparation, mise en mémoire tampon, bouton lecture) et partout dans l'app.
6. **Aucune découpe arrondie au-dessus d'AVPlayer** : Flutter 3.47 sur iOS efface tout le contenu Flutter qui
   chevauche une vue native dès qu'un `ClipRRect` s'y superpose (régression connue, flutter/flutter#191771,
   #193363, #192245) : plus de bouton lecture, de barre ni de menu sur la vidéo. Sans flou, `LiquidGlass`
   ne découpe plus rien (les coins sont peints par les décorations) ; `RoundedClip` remplace `ClipRRect` pour
   les images du lecteur (rectangle simple au-dessus d'une vue native).
7. **Liquid Glass natif sur iOS (comme Infuse)** : avec AVPlayer, le matériau du verre est dessiné par la vue
   vidéo native elle-même (`GlassOverlayView` : `UIGlassEffect` sur iOS 26, `systemUltraThinMaterialDark`
   avant), qui réfracte directement l'image. Côté Flutter, `NativeGlassScope` mesure à chaque image la
   position (zoom au toucher et glissements compris), l'arrondi et la visibilité (opacités des ancêtres) de
   chaque `LiquidGlass` et envoie la liste à la vue native quand elle change ; Flutter ne peint plus que les
   icônes et un liseré. Aucune découpe ni flou Flutter au-dessus de la vidéo. Le verre Flutter (mpv, reste de
   l'app) est éclairci : voile léger, flou plus fort avec saturation relevée, liseré spéculaire plus vif.
   Android (Media3, SurfaceView non floutable) garde le verre teinté.
