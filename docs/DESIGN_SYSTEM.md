# OptiFin — Design System

Implémentation : `lib/core/design_system/`. Aucune valeur « magique » dans les écrans :
tout passe par les tokens ci-dessous (`OFColors`, `OFSpacing`, `OFRadius`, `OFMotion`, `OFTypography`).

## 1. Couleurs (`OFColors`)

Thème sombre par défaut, noirs OLED. L'accent est **dynamique** : extrait de l'artwork
affiché (`AccentScope`), avec `accentFallback` quand aucune image n'est disponible.

| Token | Valeur | Usage |
|---|---|---|
| `background` | `#000000` | Fond d'écran (OLED) |
| `surface` | `#0E0E10` | Cartes, listes |
| `surfaceRaised` | `#18181B` | Sheets, menus |
| `surfaceGlass` | `#FFFFFF` @ 8 % + flou 24 | Barres, panneaux dépolis |
| `stroke` | `#FFFFFF` @ 10 % | Séparateurs, bordures 0,5 px |
| `textPrimary` | `#F5F5F7` | Titres, texte principal |
| `textSecondary` | `#F5F5F7` @ 64 % | Métadonnées |
| `textTertiary` | `#F5F5F7` @ 40 % | Légendes, désactivé |
| `accentFallback` | `#4DA3FF` | Accent par défaut |
| `progress` | = accent | Barre de progression |
| `success` / `warning` / `danger` | `#34C759` / `#FFB340` / `#FF453A` | États |
| `scrimTop` → `scrimBottom` | dégradé noir 0 → 92 % | Lisibilité sur backdrops |

Règle d'accent (`OFColors.normalizeAccent`) : la couleur dominante extraite est ramenée à une
luminosité HSL entre 0,55 et 0,72 et une saturation entre 0,35 et 0,85, pour rester lisible sur noir.

## 2. Typographie (`OFTypography`)

Une famille : **Inter** (Android) / **SF Pro** système (iOS). Échelle suivant le
`textScaler` du système (tailles dynamiques), plafonnée à 1,6× pour les rangées.

| Style | Taille / interligne | Graisse | Usage |
|---|---|---|---|
| `display` | 34 / 40 | 700, -0,5 tracking | Titre sans logo sur fiche |
| `title1` | 24 / 30 | 700 | Titres de page |
| `title2` | 20 / 26 | 600 | Titres de rangée |
| `headline` | 17 / 22 | 600 | Titre de carte, boutons |
| `body` | 15 / 22 | 400 | Synopsis |
| `callout` | 14 / 20 | 500 | Métadonnées |
| `caption` | 12 / 16 | 500 | Légendes, badges |

## 3. Espacements (`OFSpacing`) — grille de 4

`xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`
Marge d'écran : 20 (téléphone), 32 (tablette), 48 (tablette paysage ≥ 1200).

## 4. Rayons (`OFRadius`)

`sm 6` (badges) · `md 10` (cartes poster/paysage) · `lg 16` (sheets, boutons larges) · `pill 999`.

## 5. Mouvement (`OFMotion`)

| Token | Durée | Courbe |
|---|---|---|
| `fast` | 120 ms | `easeOut` — tap, press |
| `standard` | 220 ms | `Cubic(0.2, 0, 0, 1)` — transitions |
| `emphasized` | 300 ms | `Cubic(0.05, 0.7, 0.1, 1)` — Hero, sheets |

Toutes les durées passent par `OFMotion.of(context)` qui renvoie `Duration.zero` si
« Réduire les animations » (`MediaQuery.disableAnimations`) est actif.

## 6. Élévation & matière

- Pas d'ombres lourdes : `shadowSoft` = noir 40 %, blur 24, y 8 (cartes au survol/focus).
- Verre dépoli : `GlassSurface` (`BackdropFilter` σ=24 + `surfaceGlass` + stroke 0,5 px).
  Utilisé **uniquement** sur des zones bornées (barres, sheets) — jamais en plein écran
  défilant, pour préserver les frames.

## 7. Composants

| Composant | Description | Spécifications |
|---|---|---|
| `PosterCard` | Affiche 2:3 | Rayon `md`, placeholder BlurHash, titre optionnel dessous (`headline`/`caption`), barre de progression 3 px, pastille « vu », Hero tag `poster-<id>` |
| `LandscapeCard` | Vignette 16:9 | Pour « Reprendre », épisodes ; progression en bas, overlay dégradé pour le titre |
| `MediaRow` | Rangée horizontale | Titre `title2` + « Tout voir », `ListView.builder` virtualisé, `cacheExtent` 1 écran, padding = marge d'écran |
| `OFButton` | Boutons | `primary` (fond texte primaire, texte noir, pill, h 48), `secondary` (verre), `icon` (cercle 44, zone tactile ≥ 44) ; scale 0,96 au press + haptique légère |
| `QualityBadge` | 4K / HDR / DV / Atmos / DTS | `caption` 600, bordure stroke 1 px, rayon `sm`, monochrome (pas de logos colorés) |
| `OFSheet` | Bottom sheet | Verre, rayon `lg` en haut, poignée 36×4 |
| `OFTextField` | Champ | Fond `surface`, rayon `md`, h 52, focus = bordure accent |
| `AvatarChip` | Utilisateur | Cercle 40/64, initiales si pas d'image |
| `BackdropHeader` | En-tête immersif | Image plein cadre + scrim + parallaxe 0,3× |
| `OFImage` | Image réseau | Construit l'URL Jellyfin (`maxWidth` = taille affichée × DPR, `quality` 90, `format=Webp`), BlurHash en placeholder, fondu 150 ms |

## 8. Adaptation

- Breakpoints : `compact < 600`, `medium < 1024`, `expanded ≥ 1024`.
- Tailles de cartes poster : 112 / 136 / 160 px de large selon breakpoint.
- iOS : `CupertinoPageTransitionsBuilder` (swipe back) ; Android : prédictif back.
- Accessibilité : `Semantics` sur toutes les cartes (titre, année, progression),
  cibles ≥ 44 px, contraste AA.
