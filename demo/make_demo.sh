#!/usr/bin/env bash
# Régénère la vidéo de présentation et les captures App Store à partir de l'app réelle
# (bibliothèque fictive, illustrations générées, bande-son synthétisée).
#
#   bash demo/make_demo.sh
# Prérequis : Flutter, Node, ffmpeg.
# Sorties : docs/media/optifin-demo.mp4 (+ affiche .jpg), docs/appstore/*.png (1320×2868),
#           docs/media/appstore.jpg (aperçu du README).
set -euo pipefail
cd "$(dirname "$0")/.."

flutter test demo/capture_test.dart    # tournage : build/demo/frames/<scène>/ + build/demo/shots/
flutter test demo/stage_test.dart      # montage 1920×1080 : build/demo/stage/ + build/demo/timeline.json
flutter test demo/appstore_test.dart   # captures App Store : build/demo/appstore/
node demo/music.mjs build/demo/timeline.json build/demo/music.wav

mkdir -p docs/media docs/appstore
# Affiche : le premier plan de l'accueil avec sa phrase (sert aussi d'image 0, miniature partout).
rm -rf build/demo/stage0 && cp -r build/demo/stage build/demo/stage0
cp build/demo/stage/00150.png build/demo/stage0/00000.png
ffmpeg -loglevel error -y -i build/demo/stage/00150.png -q:v 2 docs/media/optifin-demo.jpg
ffmpeg -loglevel error -y -framerate 30 -i build/demo/stage0/%05d.png -i build/demo/music.wav \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a aac -b:a 256k -movflags +faststart \
  docs/media/optifin-demo.mp4

cp build/demo/appstore/*.png docs/appstore/
ffmpeg -loglevel error -y $(for f in build/demo/appstore/*.png; do printf -- '-i %s ' "$f"; done) \
  -filter_complex "hstack=inputs=$(ls build/demo/appstore/*.png | wc -l),scale=2400:-1:flags=lanczos" -q:v 3 \
  docs/media/appstore.jpg
echo "Vidéo : docs/media/optifin-demo.mp4 — captures App Store : docs/appstore/"
