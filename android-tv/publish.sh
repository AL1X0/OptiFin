#!/usr/bin/env bash
# Publie l'appli Android TV depuis ce poste : tests, APK signé (clé permanente hors dépôt),
# release GitHub « OptiFin TV 1.2.N » (tag tv-N) avec les fichiers des autres versions (APK
# téléphone, IPA, installateur PC) pour que la dernière release contienne toujours tout.
#
#   bash android-tv/publish.sh
#
# Prérequis : gh auth login ; signing.properties (créé une fois, voir docs/TV_ROADMAP.md).
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
export PATH="/c/Program Files/GitHub CLI:$PATH"

gh auth status >/dev/null 2>&1 || { echo "Connexion GitHub requise : gh auth login"; exit 1; }
[ -f signing.properties ] || { echo "signing.properties absent : clé de signature introuvable."; exit 1; }
[ -z "$(git status --porcelain -- .)" ] || { echo "Modifications non validées dans android-tv/ : commit d'abord."; exit 1; }

LAST=$(gh release list --limit 100 --json tagName --jq '.[].tagName' | grep '^tv-' | sed 's/tv-//' | sort -n | tail -1 || true)
N=$(( ${LAST:-0} + 1 ))
VERSION="1.2.$N"
TAG="tv-$N"
echo "Publication de OptiFin TV $VERSION ($TAG)"

./gradlew -q :app:testDebugUnitTest
./gradlew -q :app:assembleRelease -PtvBuild="$N"
APK=app/build/outputs/apk/release/app-release.apk
[ -f "$APK" ] || { echo "APK introuvable"; exit 1; }

DIST=$(mktemp -d)
cp "$APK" "$DIST/OptiFin-androidtv.apk"
MOBILE=$(gh release list --limit 50 --json tagName --jq '.[].tagName' | grep '^build-' | sort -t- -k2 -n -r | head -1 || true)
[ -n "$MOBILE" ] && gh release download "$MOBILE" --dir "$DIST" --pattern 'OptiFin.ipa' --pattern 'OptiFin-android-*.apk' --pattern 'source.json' || true
PC=$(gh release list --limit 50 --json tagName --jq '.[].tagName' | grep '^windows-' | sort -t- -k2 -n -r | head -1 || true)
[ -n "$PC" ] && gh release download "$PC" --dir "$DIST" --pattern 'OptiFin-windows-setup.exe' || true

gh release create "$TAG" "$DIST"/* --draft --target "$(git rev-parse HEAD)" \
  --title "OptiFin TV $VERSION" --notes "$(git log -1 --pretty=%B)"
gh release edit "$TAG" --draft=false --latest
rm -rf "$DIST"

# Ne garder que les 5 dernières versions TV.
gh release list --limit 100 --json tagName --jq '.[].tagName' | grep '^tv-' | sort -t- -k2 -n -r | tail -n +6 | \
  xargs -r -I{} gh release delete {} --yes --cleanup-tag
echo "Publié : OptiFin TV $VERSION"
