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
