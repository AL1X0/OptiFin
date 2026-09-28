#!/usr/bin/env bash
# Régénère la vidéo de démo et les médias du README à partir de l'app réelle
# (bibliothèque fictive, illustrations générées, musique synthétisée).
#
#   bash demo/make_demo.sh
# Prérequis : Flutter, Node, ffmpeg. Sorties : brag-output/ et docs/media, docs/screenshots.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter test demo/capture_test.dart   # tournage : build/demo/frames/<scène>/ + build/demo/shots/
flutter test demo/stage_test.dart     # montage 1920×1080 : build/demo/stage/ + build/demo/timeline.json
node demo/music.mjs build/demo/timeline.json build/demo/music.wav

# Vidéo : l'image d'affiche (accueil + accroche) sert aussi d'image 0 (miniature partout).
mkdir -p brag-output/work docs/media docs/screenshots
rm -rf build/demo/stage0 && cp -r build/demo/stage build/demo/stage0
cp build/demo/stage/00060.png build/demo/stage0/00000.png
ffmpeg -loglevel error -y -i build/demo/stage/00060.png -q:v 2 brag-output/brag.jpg
ffmpeg -loglevel error -y -framerate 30 -i build/demo/stage0/%05d.png -i build/demo/music.wav \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 192k -shortest -movflags +faststart \
  brag-output/brag.mp4
cp brag-output/brag.mp4 docs/media/optifin-demo.mp4
cp brag-output/brag.jpg docs/media/optifin-demo.jpg

# Captures d'écran (README).
for s in home home_rows details details_cast series series_episodes library search; do
  ffmpeg -loglevel error -y -i "build/demo/shots/$s.png" -vf "scale=430:-1:flags=lanczos" -q:v 3 "docs/screenshots/$s.jpg"
done
for s in player player_tracks player_upnext; do
  ffmpeg -loglevel error -y -i "build/demo/shots/$s.png" -vf "scale=900:-1:flags=lanczos" -q:v 3 "docs/screenshots/$s.jpg"
done

# GIF : une image sur deux (15 i/s), palette optimisée.
gif() { # $1 = sortie, $2 = largeur, scènes…
  local out=$1 width=$2; shift 2
  rm -rf build/demo/gif && mkdir -p build/demo/gif
  local i=0
  for scene in "$@"; do
    for f in build/demo/frames/"$scene"/*.png; do
      local n; n=$(basename "$f" .png)
      if (( 10#$n % 2 == 0 )); then cp "$f" "build/demo/gif/$(printf %05d $i).png"; i=$((i + 1)); fi
    done
  done
  ffmpeg -loglevel error -y -framerate 15 -i build/demo/gif/%05d.png \
    -vf "scale=$width:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
    -loop 0 "$out"
}
gif docs/media/tour.gif 300 home details series library search
gif docs/media/player.gif 640 player
echo "Vidéo : brag-output/brag.mp4 — médias du README : docs/media, docs/screenshots"
