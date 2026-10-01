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
8. **Barre de progression façon Infuse** : plus de Slider Material (curseur, bleu d'accent) ni de pilule
   autour. La piste est elle-même un verre sans contour (natif sur iOS), remplie de blanc à mesure de la
   lecture (tampon en blanc léger), 8 pt d'épaisseur, 13 pt pendant le glissé ; toucher = sauter au point.
   Temps écoulé et restant sous la barre.

## Encoche, barre flottante, couleur par film, carrousel plus rapide (2026-09-28)

1. **Lecteur** : lecture/pause et ±10 s sans verre (icônes seules avec ombre douce, comme Infuse).
2. **Encoche / Dynamic Island** : `OFSpacing.gutterOf(context)` ajoute la zone de sécurité latérale à la marge
   d'écran ; tous les écrans l'utilisent (en paysage, titres, rangées et grilles ne passent plus dessous).
3. **Barre d'onglets flottante partout** (téléphone portrait/paysage, tablette, Android) : icône au-dessus du
   libellé sur téléphone, côte à côte sur tablette. **Sur iOS, vrai verre natif** : `NativeGlassView`
   (vue UIKit `UIGlassEffect`/matériau flouté) sous les icônes Flutter.
4. **Couleur propre à chaque film** : l'accueil n'est plus teinté par le titre du carrousel. Les points du
   carrousel prennent la couleur du titre affiché ; la barre de progression de chaque carte, celle de son
   illustration (`FilmAccent`, même accent que la fiche).
5. **Carrousel plus rapide** : illustrations en WebP qualité 75 ; les images de la sélection de la prochaine
   ouverture sont téléchargées sur le disque pendant l'utilisation (au lancement suivant, affichage immédiat).

## Phase 7 : téléchargements hors connexion (2026-09-28)

1. **Fichier d'origine** (flux statique `Videos/{id}/stream?static=true`, en-tête d'authentification, jamais de
   token dans l'URL) : aucune perte de qualité, HDR/Dolby Vision conservés. Pas de transcodage à la volée.
2. **Transferts en arrière-plan** avec `background_downloader` (URLSession d'arrière-plan sur iOS, WorkManager sur
   Android) : l'app peut être fermée ; pause, reprise (requêtes Range), 3 nouvelles tentatives ; Wi-Fi uniquement
   par défaut (réglage « Télécharger en Wi-Fi uniquement »). Interface `FileTransfers` pour les tests et la démo.
3. **Table `Downloads`** (schéma v3) par compte : fiche (`BaseItemDto`) et réponse `PlaybackInfo` conservées en JSON,
   chemins relatifs au dossier de l'app (le chemin absolu change à chaque installation iOS), affiche et fond
   téléchargés à côté pour une liste lisible sans réseau.
4. **Lecture** : `PlaybackPreparer` lit d'abord le fichier téléchargé (hors connexion comme en ligne : aucun débit
   consommé). Plan reconstruit depuis le `PlaybackInfo` conservé ; seule la lecture directe est possible (remux,
   transcodage et sous-titres servis par Jellyfin exigent le serveur) : natif si le fichier et les sous-titres s'y
   prêtent, mpv sinon ; les replis restent sur le fichier. Fiche du lecteur reprise du téléchargement si le serveur
   est injoignable ; chapitres/segments ignorés sans réseau.
5. **Interface** : bouton rond sur les fiches (anneau de progression, coche, actions pause/reprise/annulation/
   suppression), « Télécharger la saison » et un bouton par épisode ; onglet **Téléchargements** (4e onglet) : films
   et séries regroupés (épisodes ordonnés), progression, espace occupé, glisser pour supprimer, tout supprimer.
6. **Correctif hors connexion** : le lecteur ignore un plan préchargé plus tôt (flux du serveur, gardé 2 min par
   la fiche ou le carrousel) dès qu'un fichier téléchargé existe ; avant, en mode avion, il tentait le flux du
   serveur puis son repli appelait le serveur (« Serveur injoignable »). La fiche s'ouvre hors connexion avec la
   fiche enregistrée. Au démarrage (et avant une lecture), l'état des transferts terminés app fermée est rattrapé
   depuis la base du downloader.

## Nouvelle vidéo et captures App Store (2026-09-28)

Vidéo refaite avec l'app actuelle (barre flottante, lecteur en verre, menu Réglages, téléchargements) dans un
montage épuré : fond noir, téléphone qui « respire », une phrase par plan, logo en ouverture et en fin. Bande-son
synthétisée plus sobre (nappe qui s'ouvre, piano électrique FM, impacts sur le logo, réverbération FDN), −15 LUFS.
Cinq captures au format App Store iPhone 6,9 pouces (1320 × 2868) dans `docs/appstore/`. README réduit à l'essentiel ;
les GIF et la galerie de captures sont supprimés.

## Verre interactif (2026-09-29)

1. **Barre d'onglets façon iOS 26** : l'onglet actif est une lentille de verre qui glisse d'un onglet à l'autre
   sur un ressort peu amorti, s'étire avec la vitesse, se soulève (plus grande, plus claire) et grossit les icônes
   qu'elle survole. Elle se fait glisser du doigt (petit retour haptique à chaque onglet) et se pose sur l'onglet
   le plus proche, élan compris. Onglets de largeur fixe, contenu réduit au besoin (grandes polices).
2. **`GlassPress`** sur tous les boutons en verre (ronds, pilules, grappe du lecteur, téléchargement) : au toucher
   le bouton gonfle avec un rebond et un reflet suit le doigt ; aucun calque de découpe (compatible avec le verre
   natif posé sur la vidéo).

## Optimisation Android et démarrage de la lecture (2026-09-29)

1. **Vidéo Android** : SDR (cas courant) sur `TextureView` en composition par couche de texture (la plus légère) ;
   la composition hybride + `SurfaceView` (coûteuse : threads Flutter et Android synchronisés à chaque image) est
   réservée au HDR, seule à pouvoir l'afficher. `EngineMedia.hdr` indique la nature du flux.
2. **Sous-titres superposés** : plus d'horloge à chaque image pendant tout le film ; un réveil programmé au prochain
   changement de réplique (`CueTrack.nextChangeAfter`) et aucune reconstruction tant que le texte ne change pas.
3. **Flou coupé sur Android** (`OFGlass.blur`) : chaque `BackdropFilter` refloutait l'image à chaque frame (barre
   d'onglets, boutons, en-têtes) ; le verre y est teinté, avec liseré et reflet.
4. **iOS** : le suivi du verre natif du lecteur s'endort après 0,7 s sans mouvement (il tournait à chaque image
   pendant tout le film) et se réveille au toucher, aux changements d'état, du menu et des boutons.
5. **Démarrage de la lecture** : fiche reprise de la page d'origine (plus de requête), moteur instancié d'avance dès
   que la fiche connaît le moteur retenu (`EnginePool`, libéré après 2 min), moteur de téléchargement démarré dès
   l'accueil, transition plus courte ; chronométrage de chaque étape dans les journaux (« Démarrage +N ms »).
6. **Fiche** : bouton Lecture et boutons ronds jamais sur deux lignes d'icônes : tout sur une ligne si la largeur
   le permet, sinon Lecture sur toute la largeur et les icônes sur une seule ligne en dessous.

## Android TV (2026-09-29)

Même APK que les téléphones : `OFDevice.tv` est fixé au démarrage (mode d'interface TV, fonctionnalité
`leanback` ou Fire TV) et bascule l'interface.

1. **Manifeste** : entrée `LEANBACK_LAUNCHER`, bannière 320 × 180 (`demo/tv_banner_test.dart`), écran tactile et
   leanback facultatifs. Les APK de toutes les architectures (dont 32 bits : Fire TV, Chromecast) sont publiés.
2. **Menu en haut** : pilule de verre (Accueil, Bibliothèques, Recherche, Réglages ; pas de Téléchargements) ;
   poser le focus sur un onglet l'ouvre. ▲ en haut d'une page remonte dans le menu, ▼ y redescend.
3. **Focus télécommande** (`TvFocusable`, cartes) : flèches pour se déplacer, OK pour activer, surbrillance
   (zoom, liseré, carte soulevée) uniquement quand le focus vient de la télécommande ou d'un clavier ; rangées non
   rognées sur TV ; focus initial sur « Lecture » (accueil, fiche) ; première flèche = premier élément si rien
   n'a le focus.
4. **Carrousel** : ◀ sur « Lecture » / ▶ sur « Infos » changent de titre ; pas de défilement automatique.
5. **Lecteur** : contrôles masqués, OK = lecture/pause, ◀ ▶ = ∓10 s (maintenu : ∓30 s), ▲ ▼ = contrôles ;
   touches média ; barre de progression pilotable ; menu Réglages focalisé sur sa première ligne ; Retour
   ferme le menu, puis masque les contrôles, puis quitte. Pas de verrou ni de Picture-in-Picture sur TV.
6. **Rendu** vérifié à 960 × 540 (1080p) avec une télécommande simulée : `demo/tv_audit_test.dart`.

## Android TV, deuxième version (2026-09-30)

Retours d'un premier essai sur téléviseur : navigation piégée, clavier surgissant, plantage à la bascule vers mpv.

1. **Menu latéral** (remplace la pilule du haut) : icônes à gauche, déployées avec les libellés quand on y entre.
   ◀ au bord d'une page ou Retour sur une page racine y mène ; ▲ ▼ parcourent les rubriques **sans les ouvrir** ;
   OK ouvre, ▶ ou Retour revient dans la page à l'élément quitté. Menu et page ont chacun leur portée de focus.
2. **Onglets cachés hors focus** (`ExcludeFocus`) : le focus pouvait sauter dans une page invisible, notamment le
   champ de recherche, d'où le clavier qui surgissait sans raison.
3. **Champs texte** (`TvTextEntry`) : le focus s'y pose sans ouvrir le clavier, OK l'ouvre, ▲ ▼ quittent le champ
   (Flutter gardait ces flèches pour le curseur : le bouton Quick Connect était inatteignable).
4. **Connexion TV** : présentation à gauche, choix à droite ; Quick Connect en premier et focalisé (saisir un mot
   de passe à la télécommande est pénible), code dans une fenêtre centrée ; profils sélectionnables.
5. **Lecteur TV** (`TvPlayerControls`) : tout en bas, lisible de loin — titre, barre pleine largeur, temps
   écoulé, heure de fin, temps restant ; boutons ±10 s, lecture, sous-titres, audio, format, réglages (pilule
   blanche avec libellé au focus). Barre : ◀ ▶ déplacent un aperçu (vignettes), de plus en plus vite, la lecture
   saute au relâchement ou à OK. Menu en panneau à droite, focus confiné. OK déclenche « Passer l'intro » et
   « Épisode suivant ». Le nœud racine des touches est hors du parcours des flèches (il captait le focus).
6. **Bascule vers mpv** (le repli reste) : pause de 400 ms entre les moteurs (décodeur 4K unique sur bien des
   box), `hwdec=mediacodec-copy` sur TV (l'échange direct avec le GPU fait planter des pilotes), tampons bornés.
   Dolby Vision profil 7 n'est plus annoncé hors Shield.
7. **Journal persistant** : écrit ligne à ligne dans un fichier, la session précédente est relue au lancement
   (un plantage natif reste diagnosticable) ; bouton « Envoyer au serveur » (`/ClientLog/Document`), seul moyen de
   récupérer le journal depuis un téléviseur.

## Windows natif (2026-10-01)

La version Windows en Flutter est abandonnée (deux bases de code de toute façon, et la vidéo de mpv ne se composait
pas sous l'interface Flutter : écran noir avec le son). Elle est remplacée par une appli native dans `windows-native/`.

1. **C# / .NET 10 + WinUI 3, compilé en NativeAOT** (pas de JIT ni de runtime .NET à installer) : fenêtre affichée
   en ~0,6 s. Paquets Windows App SDK séparés (WinUI, Foundation…) plutôt que le méta-paquet : 80 Mo de moins.
   Appli non empaquetée, autonome. Rust écarté : pas d'interface native Windows mûre, WinUI depuis Rust reste expérimental.
2. **Trois projets** : `OptiFin.Core` (client Jellyfin, comptes, accueil, bibliothèques, lecture, réglages — sans
   interface, testé), `OptiFin.Mpv` (libmpv en appels natifs générés), `OptiFin.App` (interface). Les règles métier
   (lignes de l'accueil, badges, libellés, choix des pistes, segments, épisode suivant) reprennent celles du mobile.
3. **Compatible AOT de bout en bout** : JSON par générateurs de source, `LibraryImport`, aucune réflexion.
   Piège rencontré : en AOT, un `Style` lu dans les ressources peut revenir comme simple `DependencyObject` ;
   `Ui.StyleOf` / `Ui.Res` demandent alors explicitement l'interface WinRT.
4. **Lecteur** : libmpv (gpu-next, Direct3D 11, décodage matériel, HDR transmis à l'écran) dans une fenêtre Win32 à
   elle ; les commandes WinUI sont dans une seconde fenêtre transparente posée au-dessus et synchronisée (une fenêtre
   enfant serait toujours dessinée par-dessus le XAML). libmpv (build shinchiro) est téléchargée à la compilation et
   vérifiée par SHA-256. Repli automatique sur le transcodage si la lecture directe échoue au démarrage.
5. **Jetons** chiffrés par DPAPI (liés à la session Windows), jamais dans les URL d'images ni dans le journal.
6. **Intégrations** : contrôles multimédias de Windows (touches média, écran de verrouillage), identité d'appli
   `OptiFin.Windows`, placement de fenêtre mémorisé, Ctrl+F, Alt+←, bouton « précédent » de la souris.
7. **Installateur Inno Setup** par utilisateur (même AppId que l'ancienne version Flutter, qu'il remplace) ;
   la CI le joint à chaque Release. **Mise à jour automatique** : l'appli consulte la dernière Release, vérifie
   l'empreinte SHA-256 publiée par GitHub et relance l'installateur en silencieux.
8. **Vérification visuelle** sans écran : `OptiFin.exe --capture dossier étape=action…` capture la fenêtre ;
   `tools/OptiFin.DemoServer` simule un serveur Jellyfin (catalogue et images générées).
9. **Non vérifiable ici** (machine virtuelle sans GPU) : rendu HDR réel et superposition des commandes au-dessus de
   la vidéo.
