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
