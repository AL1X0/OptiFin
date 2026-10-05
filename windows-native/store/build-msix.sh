#!/usr/bin/env bash
# Construit le paquet Microsoft Store (out/store/OptiFin-<version>.msix), à importer dans
# Partner Center. Non signé : le Store le signe à la publication.
#
#   bash windows-native/store/build-msix.sh            # version de la dernière release PC (1.1.N)
#   bash windows-native/store/build-msix.sh 1.1.12     # version choisie
#
# Identité du paquet : store/identity.env (copiée depuis Partner Center).
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/c/Program Files/dotnet:/c/Program Files (x86)/Microsoft Visual Studio/Installer:/c/Program Files/GitHub CLI:$PATH"
. store/identity.env

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  N=$(gh release list --limit 100 --json tagName --jq '.[].tagName' | grep '^windows-' | sed 's/windows-//' | sort -n | tail -1)
  VERSION="1.1.${N:-0}"
fi
echo "Paquet Store OptiFin $VERSION ($STORE_NAME)"

# Le Store exige une version à 4 nombres dont le dernier vaut 0.
MANIFEST="$PWD/out/store/Package.appxmanifest"
mkdir -p out/store
sed -e "s|__NAME__|$STORE_NAME|" -e "s|__PUBLISHER__|$STORE_PUBLISHER|" -e "s|__PUBLISHER_NAME__|$STORE_PUBLISHER_NAME|" \
    -e "s|__VERSION__|$VERSION.0|" store/Package.appxmanifest.template > "$MANIFEST"

rm -rf out/store/pkg
dotnet publish src/OptiFin.App/OptiFin.App.csproj -c Release -r win-x64 -p:Platform=x64 -p:Version="$VERSION" \
  -p:WindowsPackageType=MSIX -p:StoreManifest="$MANIFEST" -p:AppxPackageDir="$PWD/out/store/pkg/" -nologo -v q

MSIX=$(find out/store/pkg -name '*.msix' | head -1)
[ -n "$MSIX" ] || { echo "Paquet introuvable"; exit 1; }
cp "$MSIX" "out/store/OptiFin-$VERSION.msix"
echo "Prêt : windows-native/out/store/OptiFin-$VERSION.msix ($(du -m "out/store/OptiFin-$VERSION.msix" | cut -f1) Mo)"
