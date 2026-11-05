#!/usr/bin/env bash
# Publie une version de l'appli PC partout, en une commande : release GitHub (tests, compilation, test
# réel du binaire, installateur) puis Microsoft Store. Vérifie d'abord que les deux pourront aboutir :
# nouveautés écrites dans CHANGELOG.md, et pas de soumission Store déjà en certification.
#
#   bash windows-native/release.sh
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/c/Program Files/GitHub CLI:$PATH"

LAST=$(gh release list --limit 100 --json tagName --jq '.[].tagName' | grep '^windows-' | sed 's/windows-//' | sort -n | tail -1)
VERSION="1.1.$(( ${LAST:-0} + 1 ))"
bash tools/release-notes.sh "$VERSION" >/dev/null
python store/submit.py --etat --bloquant

bash publish.sh
bash store/publish-store.sh "$VERSION"
echo "OptiFin Windows $VERSION : release GitHub en ligne, soumission Store envoyée."
echo "Suivi de la certification : python windows-native/store/submit.py --etat"
