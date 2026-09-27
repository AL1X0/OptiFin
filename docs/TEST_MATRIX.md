# Matrice de test des moteurs de lecture

Pour chaque fichier type et chaque profil d'appareil type : le moteur choisi par
l'`EngineSelector`, le mode de livraison et le rendu des sous-titres.

- **Natif** : AVPlayer (iOS) ou Media3/ExoPlayer (Android). **mpv** : libmpv via media_kit.
- **Lecture directe** : fichier lu tel quel. **Remux** : le serveur réemballe en HLS fMP4
  (vidéo copiée, HDR et Dolby Vision intacts, audio converti si besoin). **Transcodage** :
  vidéo ré-encodée par le serveur.
- **ST moteur** : sous-titres rendus par mpv (libass, PGS). **ST OptiFin** : texte servi
  en WebVTT par Jellyfin et dessiné par OptiFin au-dessus de la vidéo native.
  **ST incrustés** : dessinés dans l'image par le serveur.

La table ci-dessous est **générée** à partir des tests
(`test/features/player/engine_matrix.dart`) : elle ne peut pas diverger du code.
Pour la régénérer après une évolution des règles :

```bash
UPDATE_MATRIX=1 flutter test test/features/player/engine_selector_test.dart
```

## Décisions

<!-- matrice:début -->
| Fichier | iPhone 15 Pro (iOS 18) | iPhone 11 (sans AV1) | Pixel 8 (Android 15, HDR sans DV) | Android entrée de gamme (1080p, SDR) | Box Android TV Dolby Vision |
|---|---|---|---|---|---|
| MP4 H.264 1080p, AAC, SRT externe | **Natif** · Lecture directe, ST OptiFin | **Natif** · Lecture directe, ST OptiFin | **Natif** · Lecture directe, ST OptiFin | **Natif** · Lecture directe, ST OptiFin | **Natif** · Lecture directe, ST OptiFin |
| MKV HEVC 10 bits HDR10 4K, E-AC3 5.1 | **Natif** · Remux | **Natif** · Remux | **Natif** · Lecture directe | **Natif** · Transcodage | **Natif** · Lecture directe |
| MKV DV profil 8.1 4K, TrueHD Atmos, PGS | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur | **Natif** · Transcodage, ST incrustés | **mpv** · Lecture directe, ST moteur |
| MKV DV profil 8.1 4K, TrueHD Atmos, sans sous-titres | **Natif** · Remux | **Natif** · Remux | **Natif** · Remux | **Natif** · Transcodage | **Natif** · Lecture directe |
| MP4 DV profil 5 4K, E-AC3 Atmos | **Natif** · Lecture directe | **Natif** · Lecture directe | **Natif** · Transcodage | **Natif** · Transcodage | **Natif** · Lecture directe |
| MKV DV profil 7 (BL+EL) 4K, TrueHD | **Natif** · Remux | **Natif** · Remux | **Natif** · Remux | **Natif** · Transcodage | **Natif** · Lecture directe |
| MKV AV1 10 bits HDR10 4K, Opus 5.1 | **Natif** · Remux | **Natif** · Transcodage | **Natif** · Lecture directe | **Natif** · Transcodage | **Natif** · Lecture directe |
| MKV HEVC HLG 4K, AAC | **Natif** · Remux | **Natif** · Remux | **Natif** · Lecture directe | **Natif** · Transcodage | **Natif** · Lecture directe |
| MKV H.264 1080p, DTS-HD MA 7.1 | **mpv** · Lecture directe | **mpv** · Lecture directe | **mpv** · Lecture directe | **mpv** · Lecture directe | **Natif** · Lecture directe |
| MKV H.264 1080p, AAC, ASS | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur |
| MKV HEVC 1080p SDR, AC3, PGS | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur | **mpv** · Lecture directe, ST moteur |
| MP4 H.264 1080p, AC3, sous-titres mov_text | **Natif** · Lecture directe, ST OptiFin | **Natif** · Lecture directe, ST OptiFin | **Natif** · Lecture directe, ST OptiFin | **mpv** · Lecture directe, ST moteur | **Natif** · Lecture directe, ST OptiFin |
| WebM VP9 1080p, Opus | **mpv** · Lecture directe | **mpv** · Lecture directe | **Natif** · Lecture directe | **mpv** · Lecture directe | **Natif** · Lecture directe |
| AVI MPEG-4 ASP (Xvid) 480p, MP3 | **mpv** · Lecture directe | **mpv** · Lecture directe | **mpv** · Lecture directe | **mpv** · Lecture directe | **mpv** · Lecture directe |
| MKV VC-1 1080p, AC3 | **mpv** · Lecture directe | **mpv** · Lecture directe | **mpv** · Lecture directe | **mpv** · Lecture directe | **mpv** · Lecture directe |
| MKV AV1 4K SDR, Opus | **mpv** · Lecture directe | **Natif** · Transcodage | **Natif** · Lecture directe | **Natif** · Transcodage | **Natif** · Lecture directe |

### Raisons et replis

**MP4 H.264 1080p, AAC, SRT externe**

- iPhone 15 Pro (iOS 18) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- iPhone 11 (sans AV1) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- Box Android TV Dolby Vision : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage

**MKV HEVC 10 bits HDR10 4K, E-AC3 5.1**

- iPhone 15 Pro (iOS 18) : HDR10 : lecteur natif (remux : conteneur MKV) — replis : mpv · Lecture directe → mpv · Transcodage
- iPhone 11 (sans AV1) : HDR10 : lecteur natif (remux : conteneur MKV) — replis : mpv · Lecture directe → mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : HDR10 : lecteur natif — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : Aucun moteur ne lit ce fichier tel quel (HEVC 10 bits non pris en charge ; HEVC 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Box Android TV Dolby Vision : HDR10 : lecteur natif — replis : mpv · Lecture directe → mpv · Transcodage

**MKV DV profil 8.1 4K, TrueHD Atmos, PGS**

- iPhone 15 Pro (iOS 18) : Sous-titres image sur du Dolby Vision : rendus par mpv (sinon incrustation serveur) — replis : Natif · Transcodage
- iPhone 11 (sans AV1) : Sous-titres image sur du Dolby Vision : rendus par mpv (sinon incrustation serveur) — replis : Natif · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : Sous-titres image sur du Dolby Vision (couche de base HDR10) : rendus par mpv (sinon incrustation serveur) — replis : Natif · Transcodage
- Android entrée de gamme (1080p, SDR) : Aucun moteur ne lit ce fichier tel quel (HEVC 10 bits non pris en charge ; HEVC 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Box Android TV Dolby Vision : Sous-titres image sur du Dolby Vision : rendus par mpv (sinon incrustation serveur) — replis : Natif · Transcodage

**MKV DV profil 8.1 4K, TrueHD Atmos, sans sous-titres**

- iPhone 15 Pro (iOS 18) : Dolby Vision : lecteur natif (remux : conteneur MKV, audio TrueHD Atmos converti) — replis : mpv · Lecture directe → mpv · Transcodage
- iPhone 11 (sans AV1) : Dolby Vision : lecteur natif (remux : conteneur MKV, audio TrueHD Atmos converti) — replis : mpv · Lecture directe → mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : Dolby Vision (couche de base HDR10) : lecteur natif (remux : audio TrueHD Atmos converti) — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : Aucun moteur ne lit ce fichier tel quel (HEVC 10 bits non pris en charge ; HEVC 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Box Android TV Dolby Vision : Dolby Vision : lecteur natif — replis : mpv · Lecture directe → mpv · Transcodage

**MP4 DV profil 5 4K, E-AC3 Atmos**

- iPhone 15 Pro (iOS 18) : Dolby Vision : lecteur natif — replis : mpv · Transcodage
- iPhone 11 (sans AV1) : Dolby Vision : lecteur natif — replis : mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : Aucun moteur ne lit ce fichier tel quel (Dolby Vision profil 5 sans couche de base compatible ; Dolby Vision profil 5 : couleurs faussées hors lecteur Dolby Vision) : transcodage — replis : mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : Aucun moteur ne lit ce fichier tel quel (HEVC 10 bits non pris en charge ; Dolby Vision profil 5 : couleurs faussées hors lecteur Dolby Vision) : transcodage — replis : mpv · Transcodage
- Box Android TV Dolby Vision : Dolby Vision : lecteur natif — replis : mpv · Transcodage

**MKV DV profil 7 (BL+EL) 4K, TrueHD**

- iPhone 15 Pro (iOS 18) : Dolby Vision (couche de base HDR10) : lecteur natif (remux : conteneur MKV, audio TrueHD Atmos converti) — replis : mpv · Lecture directe → mpv · Transcodage
- iPhone 11 (sans AV1) : Dolby Vision (couche de base HDR10) : lecteur natif (remux : conteneur MKV, audio TrueHD Atmos converti) — replis : mpv · Lecture directe → mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : Dolby Vision (couche de base HDR10) : lecteur natif (remux : audio TrueHD Atmos converti) — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : Aucun moteur ne lit ce fichier tel quel (HEVC 10 bits non pris en charge ; HEVC 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Box Android TV Dolby Vision : Dolby Vision : lecteur natif — replis : mpv · Lecture directe → mpv · Transcodage

**MKV AV1 10 bits HDR10 4K, Opus 5.1**

- iPhone 15 Pro (iOS 18) : HDR10 : lecteur natif (remux : conteneur MKV, audio OPUS converti) — replis : mpv · Lecture directe → mpv · Transcodage
- iPhone 11 (sans AV1) : Aucun moteur ne lit ce fichier tel quel (codec vidéo AV1 non pris en charge ; AV1 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : HDR10 : lecteur natif — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : Aucun moteur ne lit ce fichier tel quel (codec vidéo AV1 non pris en charge ; AV1 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Box Android TV Dolby Vision : HDR10 : lecteur natif — replis : mpv · Lecture directe → mpv · Transcodage

**MKV HEVC HLG 4K, AAC**

- iPhone 15 Pro (iOS 18) : HLG : lecteur natif (remux : conteneur MKV) — replis : mpv · Lecture directe → mpv · Transcodage
- iPhone 11 (sans AV1) : HLG : lecteur natif (remux : conteneur MKV) — replis : mpv · Lecture directe → mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : HLG : lecteur natif — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : Aucun moteur ne lit ce fichier tel quel (HEVC 10 bits non pris en charge ; HEVC 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Box Android TV Dolby Vision : HLG : lecteur natif — replis : mpv · Lecture directe → mpv · Transcodage

**MKV H.264 1080p, DTS-HD MA 7.1**

- iPhone 15 Pro (iOS 18) : mpv : conteneur MKV, audio DTS-HD MA — replis : Natif · Remux → Natif · Transcodage
- iPhone 11 (sans AV1) : mpv : conteneur MKV, audio DTS-HD MA — replis : Natif · Remux → Natif · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : mpv : audio DTS-HD MA — replis : Natif · Remux → Natif · Transcodage
- Android entrée de gamme (1080p, SDR) : mpv : audio DTS-HD MA — replis : Natif · Remux → Natif · Transcodage
- Box Android TV Dolby Vision : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage

**MKV H.264 1080p, AAC, ASS**

- iPhone 15 Pro (iOS 18) : mpv : conteneur MKV, sous-titres ASS — replis : Natif · Remux → Natif · Transcodage
- iPhone 11 (sans AV1) : mpv : conteneur MKV, sous-titres ASS — replis : Natif · Remux → Natif · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : mpv : sous-titres ASS — replis : Natif · Lecture directe → Natif · Transcodage
- Android entrée de gamme (1080p, SDR) : mpv : sous-titres ASS — replis : Natif · Lecture directe → Natif · Transcodage
- Box Android TV Dolby Vision : mpv : sous-titres ASS — replis : Natif · Lecture directe → Natif · Transcodage

**MKV HEVC 1080p SDR, AC3, PGS**

- iPhone 15 Pro (iOS 18) : mpv : conteneur MKV, sous-titres image — replis : Natif · Transcodage
- iPhone 11 (sans AV1) : mpv : conteneur MKV, sous-titres image — replis : Natif · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : mpv : sous-titres image — replis : Natif · Transcodage
- Android entrée de gamme (1080p, SDR) : mpv : audio AC3, sous-titres image — replis : Natif · Transcodage
- Box Android TV Dolby Vision : mpv : sous-titres image — replis : Natif · Transcodage

**MP4 H.264 1080p, AC3, sous-titres mov_text**

- iPhone 15 Pro (iOS 18) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- iPhone 11 (sans AV1) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : mpv : audio AC3 — replis : Natif · Remux → Natif · Transcodage
- Box Android TV Dolby Vision : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage

**WebM VP9 1080p, Opus**

- iPhone 15 Pro (iOS 18) : mpv : codec vidéo VP9 non pris en charge, conteneur WEBM, audio OPUS — replis : Natif · Transcodage
- iPhone 11 (sans AV1) : mpv : codec vidéo VP9 non pris en charge, conteneur WEBM, audio OPUS — replis : Natif · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : mpv : codec vidéo VP9 non pris en charge — replis : Natif · Transcodage
- Box Android TV Dolby Vision : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage

**AVI MPEG-4 ASP (Xvid) 480p, MP3**

- iPhone 15 Pro (iOS 18) : mpv : codec vidéo MPEG4 non pris en charge, conteneur AVI — replis : Natif · Transcodage
- iPhone 11 (sans AV1) : mpv : codec vidéo MPEG4 non pris en charge, conteneur AVI — replis : Natif · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : mpv : codec vidéo MPEG4 non pris en charge, conteneur AVI — replis : Natif · Transcodage
- Android entrée de gamme (1080p, SDR) : mpv : codec vidéo MPEG4 non pris en charge, conteneur AVI — replis : Natif · Transcodage
- Box Android TV Dolby Vision : mpv : codec vidéo MPEG4 non pris en charge, conteneur AVI — replis : Natif · Transcodage

**MKV VC-1 1080p, AC3**

- iPhone 15 Pro (iOS 18) : mpv : codec vidéo VC1 non pris en charge, conteneur MKV — replis : Natif · Transcodage
- iPhone 11 (sans AV1) : mpv : codec vidéo VC1 non pris en charge, conteneur MKV — replis : Natif · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : mpv : codec vidéo VC1 non pris en charge — replis : Natif · Transcodage
- Android entrée de gamme (1080p, SDR) : mpv : codec vidéo VC1 non pris en charge, audio AC3 — replis : Natif · Transcodage
- Box Android TV Dolby Vision : mpv : codec vidéo VC1 non pris en charge — replis : Natif · Transcodage

**MKV AV1 4K SDR, Opus**

- iPhone 15 Pro (iOS 18) : mpv : conteneur MKV, audio OPUS — replis : Natif · Remux → Natif · Transcodage
- iPhone 11 (sans AV1) : Aucun moteur ne lit ce fichier tel quel (codec vidéo AV1 non pris en charge ; AV1 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Pixel 8 (Android 15, HDR sans DV) : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
- Android entrée de gamme (1080p, SDR) : Aucun moteur ne lit ce fichier tel quel (codec vidéo AV1 non pris en charge ; AV1 3840 px sans décodage matériel) : transcodage — replis : mpv · Transcodage
- Box Android TV Dolby Vision : Lecture directe native — replis : mpv · Lecture directe → mpv · Transcodage
<!-- matrice:fin -->

## Résultats sur appareil

À compléter lors des essais réels (fichiers de test sur un serveur Jellyfin 10.10+,
Paramètres › Mode debug activé pour voir moteur, mode et raison dans l'overlay).

| Fichier | Appareil | Moteur observé | Premier frame | Résultat |
|---|---|---|---|---|
| MKV DV profil 8.1 4K, TrueHD Atmos | iPhone (DV) | | | à vérifier |
| MP4 DV profil 5 4K, E-AC3 Atmos | iPhone (DV) | | | à vérifier |
| MKV HEVC 10 bits HDR10 4K, E-AC3 5.1 | iPhone | | | à vérifier |
| MKV H.264 1080p, DTS-HD MA 7.1 | iPhone | | | à vérifier |
| MKV H.264 1080p, AAC, ASS | iPhone / Android | | | à vérifier |
| MKV HEVC 1080p SDR, AC3, PGS | iPhone / Android | | | à vérifier |
| MKV AV1 10 bits HDR10 4K, Opus 5.1 | Android | | | à vérifier |
| MP4 H.264 1080p, AAC, SRT externe | iPhone / Android | | | à vérifier |
