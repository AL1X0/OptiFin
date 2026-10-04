# OptiFin TV — feuille de route (application Android TV native)

Objectif : remplacer l'APK Flutter « hybride » sur téléviseur par une application **dédiée TV**,
conçue dès le départ pour l'écran à 3 m et la télécommande, avec toutes les fonctions actuelles.
Les applis mobiles (Flutter), PC (C# / WinUI) restent inchangées.

## Choix techniques

| Sujet | Choix | Pourquoi |
|---|---|---|
| Langage / UI | **Kotlin + Jetpack Compose for TV** (`androidx.tv:tv-material`) | Kit officiel Google TV : focus, rangées, carrousels et zoom au focus natifs ; la navigation télécommande est gérée par le système, pas réinventée. |
| Dossier | `android-tv/` (Gradle, comme `windows-native/` pour le PC) | Code séparé, build et release indépendants. |
| Identifiant | **`app.optifin.optifin`** (inchangé, pour toujours) | Installé par-dessus l'APK actuel de la TV, comptes et réglages repris via reconnexion. Code de version > builds Flutter. |
| Réseau / Jellyfin | OkHttp + Kotlinx Serialization, client Jellyfin maison (même logique que `OptiFin.Core` C#) | Léger, maîtrisé, mêmes règles que les autres versions (profils, rapports de lecture). |
| Images | Coil 3 | Cache disque, décodage à la taille, fondus. |
| Lecteur principal | **Media3 ExoPlayer** + extension **FFmpeg** (audio TrueHD/DTS/…) | Moteur natif de la TV : HDR10/HDR10+/Dolby Vision, passthrough audio, rendu direct dans une `SurfaceView`. |
| Lecteur de repli | **libmpv** (JNI, `SurfaceView` dédiée, comme mpv-android) | Fichiers exotiques, sous-titres ASS/PGS fidèles. Rendu natif, sans couche Flutter (fin des écrans noirs / figés). |
| Stockage | DataStore (réglages) + Keystore (jetons chiffrés) | Jetons jamais en clair. |
| Tests | JUnit (logique, client Jellyfin sur serveur local), Compose UI tests avec **D-pad simulé** sur chaque écran | La navigation télécommande est vérifiée automatiquement, écran par écran. |
| Publication | Script local `android-tv/publish.sh` (comme le PC) → asset `OptiFin-androidtv.apk` dans la release | Pas de recompilation mobile ; mise à jour intégrée à l'appli. |

## Principes de conception TV

- Focus toujours visible et prévisible : zoom doux + halo, jamais de « focus perdu ».
- ▲ revient toujours en haut de page ; ◀ depuis le bord gauche ouvre le menu ; Retour : menu → accueil → quitter.
- Zones de sécurité 5 %, textes lisibles à 3 m, contrastes forts.
- Animations sobres partout (fondus, glissements courts), indépendantes du réglage « animations » du système.
- Fond d'écran d'ambiance : l'image de l'élément focalisé en fond flouté (style Google TV / Apple TV).

## Étapes

### Étape 0 — Socle (projet, CI locale, design system)
- Projet Gradle `android-tv/`, manifest leanback (bannière, pas de tactile requis), icône, bannière.
- Thème OptiFin (couleurs, typographie TV, formes), composants de base : bouton, pilule, carte, rangée, squelettes de chargement, notifications.
- Journal persistant (consultable dans l'appli, envoi), gestion des erreurs.
- Script `publish.sh` + tests JUnit. **Livrable : appli vide installable par-dessus l'actuelle.**

### Étape 1 — Connexion et comptes
- Découverte des serveurs du réseau, saisie d'adresse (clavier TV), test du serveur.
- Connexion identifiant / mot de passe, **Quick Connect** (code à valider depuis un autre appareil — idéal sur TV), choix d'utilisateur avec avatars.
- Plusieurs comptes et serveurs, bascule rapide, déconnexion. Jetons chiffrés.

### Étape 2 — Navigation et accueil
- Menu latéral TV (Recherche, Accueil, Bibliothèques, Soirée, Compte, Réglages) qui se déploie au focus.
- Accueil : carrousel « À la une » plein écran (fondu, logo du film), rangées Reprendre / À suivre / Ajouts récents par bibliothèque / Favoris, couleur d'accent par film, fond d'ambiance.
- Rafraîchissement après lecture (progression, Reprendre).

### Étape 3 — Bibliothèques et recherche
- Liste des bibliothèques ; grille virtualisée (affiches / paysage), tri, sens, filtres (vus, favoris, genres, années, résolution), saut alphabétique.
- Recherche : clavier TV + recherche vocale de la télécommande, résultats par type (films, séries, épisodes, personnes).

### Étape 4 — Fiches
- Film : fond, logo, méta (année, durée, note, classification), synopsis, boutons Lecture / Reprendre / Depuis le début / Vu / Favori / Bande-annonce, infos techniques, distribution, similaires.
- Série : saisons, épisodes (vignettes, progression, vu), épisode suivant ; saison ; collection ; page Personne (filmographie).
- Clic long (touche OK maintenue) / menu : marquer vu, favoris, aller à la série.

### Étape 5 — Lecteur (le cœur)
- Sélection du moteur (même logique que l'EngineSelector actuel) : lecture directe ExoPlayer, remux, transcodage serveur ; profils d'appareil (HDR10/HDR10+/DV, codecs, débit max).
- Contrôles façon Apple TV : barre de progression avec **vignettes trickplay**, ◀ ▶ = ±10 s (maintenu = accéléré), OK = pause, ▼ = pistes, chapitres, Retour masque puis quitte.
- Pistes audio / sous-titres (texte, ASS, PGS), style des sous-titres, décalages audio et sous-titres, recherche de sous-titres en ligne.
- Segments (passer l'intro / le générique, automatique ou non), épisode suivant avec compte à rebours.
- Rapports de lecture Jellyfin (début, progression, pause, fin) : reprise exacte partout.
- Panneau de debug (codec, débit, images perdues, HDR, moteur).
- **mpv de repli** en `SurfaceView` (JNI) avec bascule automatique si ExoPlayer échoue.

### Étape 6 — Soirées (SyncPlay)
- Créer / rejoindre / quitter, participants, synchronisation (horloge serveur, correction de dérive), l'hôte qui quitte arrête la lecture pour tous. Compatible avec les versions mobile, PC et Jellyfin web.

### Étape 7 — Réglages et finitions
- Lecture (moteur préféré, débit max, langues audio/sous-titres, sous-titres d'images, segments, épisode suivant), sous-titres (taille, fond), comptes, cache, journaux, debug, à propos, licences.
- **Mise à jour intégrée** (release GitHub, téléchargement et installation de l'APK TV).
- Écran d'accueil Android TV : chaînes / « Continuer à regarder » (Watch Next) sur le lanceur.

### Étape 8 — Validation et bascule
- Tests D-pad automatisés sur tous les écrans, tests du lecteur sur le serveur Jellyfin local.
- Publication `OptiFin-androidtv.apk` ; la release continue de proposer les APK mobiles pour les téléphones.
- Retrait du mode TV de l'appli Flutter (elle reste pour téléphones et tablettes).

## Ordre de livraison proposé

Chaque étape se termine par une version installable sur la TV : 0 → 1 → 2 → 4 → 5 (lecteur
ExoPlayer) → 3 → 6 → 7 → 5 bis (mpv) → 8. Le lecteur arrive tôt : c'est l'essentiel à valider sur
ta TV.
