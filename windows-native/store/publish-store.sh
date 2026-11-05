#!/usr/bin/env bash
# Publie la dernière version PC sur le Microsoft Store : construit le paquet (build-msix.sh), puis le
# soumet (submit.py) avec les nouveautés de windows-native/CHANGELOG.md.
#
#   bash windows-native/store/publish-store.sh            # dernière release windows-N
#   bash windows-native/store/publish-store.sh 1.1.17     # version choisie
#
# Identifiants : windows-native/store/store.env (local ; modèle : store.env.example).
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/c/Program Files/GitHub CLI:$PATH"
[ -f store/store.env ] || { echo "store/store.env manquant : voir store/store.env.example"; exit 1; }

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  N=$(gh release list --limit 100 --json tagName --jq '.[].tagName' | grep '^windows-' | sed 's/windows-//' | sort -n | tail -1)
  VERSION="1.1.$N"
fi
python store/submit.py --etat --bloquant
mkdir -p out/store
NOTES=out/store/nouveautes-$VERSION.txt
bash tools/release-notes.sh "$VERSION" > "$NOTES"
bash store/build-msix.sh "$VERSION"
python store/submit.py "out/store/OptiFin-$VERSION.msix" --notes "$NOTES"
