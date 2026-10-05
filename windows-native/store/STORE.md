# OptiFin sur le Microsoft Store

Le Store signe le paquet : plus d'alerte « éditeur inconnu », installation et mises à jour par le Store.
L'installateur `.exe` des releases GitHub reste disponible (avec sa propre mise à jour automatique).

## 1. Identité du paquet (une seule fois)

Partner Center › OptiFin › **Gestion des produits › Identité du produit** : recopier dans `store/identity.env`

| Partner Center | identity.env |
|---|---|
| Package/Identity/Name | `STORE_NAME` |
| Package/Identity/Publisher (`CN=…`) | `STORE_PUBLISHER` |
| Package/Properties/PublisherDisplayName | `STORE_PUBLISHER_NAME` |

Ce ne sont pas des secrets (ils figurent dans chaque paquet publié).

## 2. Construire le paquet

```bash
bash windows-native/store/build-msix.sh
```

→ `windows-native/out/store/OptiFin-1.1.N.msix` (non signé : le Store le signe). Chaque nouvelle soumission doit
avoir une version plus élevée que la précédente (`build-msix.sh 1.1.12` pour la forcer).

## 3. Soumission (Démarrer la soumission)

**Tarification et disponibilité** : Gratuit · tous les marchés (ou France/Belgique/Suisse/Canada) · Public.

**Propriétés**
- Catégorie : **Divertissement** (ou Photo et vidéo).
- Politique de confidentialité : `https://github.com/AL1X0/OptiFin/blob/main/docs/PRIVACY.md`
- Site web : `https://github.com/AL1X0/OptiFin` · Support : `https://github.com/AL1X0/OptiFin/issues`
- Configuration requise : Windows 10 version 2004 (19041) ou plus récent, x64.

**Classification par âge** (questionnaire IARC) : catégorie « Application » (pas un jeu, pas un navigateur).
Répondre selon ce que fait l'appli : pas d'achats, pas de publicité, pas de partage de position, pas d'échange de
messages entre utilisateurs ; elle affiche uniquement les médias du serveur personnel de l'utilisateur.

**Packages** : importer `OptiFin-1.1.N.msix`.

**Description du Store (français)**
- Description :

  > OptiFin est un lecteur élégant pour votre serveur Jellyfin. Retrouvez vos films et séries dans une interface
  > soignée : carrousel à la une, fiches détaillées avec logos et badges 4K, Dolby Vision et Atmos, reprise de
  > lecture synchronisée avec tous vos appareils.
  >
  > Le lecteur intégré (mpv) lit directement presque tous les formats, avec HDR, sous-titres fidèles (ASS, PGS),
  > choix des pistes audio, « Passer l'intro » et épisode suivant automatique.
  >
  > Organisez des soirées à plusieurs : chacun chez soi, la lecture, la pause et l'avance restent synchronisées.
  >
  > OptiFin nécessite un serveur Jellyfin (10.9 ou plus récent). Aucune donnée n'est collectée : l'appli ne
  > communique qu'avec votre serveur.

- Nouveautés de cette version : reprendre le message du commit / de la release.
- Fonctionnalités clés (une par ligne) :
  - Connexion à votre serveur Jellyfin, plusieurs comptes et serveurs
  - Lecteur mpv : HDR, 4K, sous-titres ASS et PGS, pistes audio
  - Passer l'intro, épisode suivant automatique
  - Reprise synchronisée avec tous vos appareils
  - Soirées à plusieurs synchronisées (SyncPlay)
  - Raccourcis clavier complets, plein écran
- Captures d'écran : `windows-native/store/screenshots/` (1 à 5, dans l'ordre).
- Logo du Store : `assets/branding/icon_1024.png` (format carré 1:1, ≥ 300 px).
- Mots-clés : Jellyfin, lecteur vidéo, films, séries, streaming, media center, mpv.

**Options de soumission › Notes pour la certification** (les testeurs de Microsoft doivent pouvoir se connecter) :

  > OptiFin est un client pour serveurs Jellyfin. Pour le tester, utilisez le serveur de démonstration public de
  > Jellyfin : adresse https://demo.jellyfin.org/stable, utilisateur « demo », mot de passe vide.
  > La capacité runFullTrust est nécessaire : c'est une application de bureau WinUI 3 dont le lecteur vidéo
  > (libmpv) s'exécute dans le processus de l'appli.

(Vérifier avant d'envoyer que le serveur de démonstration répond.)

Puis **Envoyer au Store** : vérification de quelques heures à quelques jours.

## Notes techniques

- Paquet construit par `dotnet publish -p:WindowsPackageType=MSIX` (même NativeAOT, Windows App SDK embarqué),
  manifeste `store/Package.appxmanifest.template`, images générées par `store/make-assets.ps1`.
- Constante `STORE` : la recherche de mises à jour intégrée est désactivée (le Store s'en charge).
- Windows peut isoler les données de l'appli Store de celles de la version `.exe` (applis
  empaquetées) : se reconnecter si les comptes n'apparaissent pas.
