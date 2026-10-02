#!/usr/bin/env bash
# Publie l'appli PC depuis ce poste, sans GitHub Actions : tests, compilation NativeAOT,
# installateur, puis release GitHub « OptiFin Windows 1.1.N » (avec les fichiers mobiles de la
# dernière build, comme le workflow). Nécessite une fois : gh auth login.
#
#   bash windows-native/publish.sh
#
# Signature de code (supprime l'avertissement « Éditeur inconnu » de Windows) : certificat de
# signature installé dans le magasin Windows de l'utilisateur (clé PFX importée, carte ou
# certificat cloud type Certum SimplySign), désigné par son empreinte SHA-1 :
#
#   OPTIFIN_SIGN_SHA1=<empreinte> bash windows-native/publish.sh
#
# (ou la mettre dans windows-native/.sign, ignoré par git). Sans certificat : version non signée.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/c/Program Files/dotnet:/c/Program Files (x86)/Microsoft Visual Studio/Installer:/c/Program Files/GitHub CLI:$PATH"
ISCC="${ISCC:-$LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe}"
SIGNTOOL=$(ls "/c/Program Files (x86)/Windows Kits/10/bin/"*/x64/signtool.exe 2>/dev/null | tail -1 || true)
[ -z "${OPTIFIN_SIGN_SHA1:-}" ] && [ -f .sign ] && OPTIFIN_SIGN_SHA1=$(tr -d ' 
' < .sign)
sign() {
  [ -n "${OPTIFIN_SIGN_SHA1:-}" ] || return 0
  "$SIGNTOOL" sign //sha1 "$OPTIFIN_SIGN_SHA1" //fd sha256 //tr "${OPTIFIN_SIGN_TIMESTAMP:-http://time.certum.pl}" //td sha256 //d OptiFin "$@"
  "$SIGNTOOL" verify //pa "$@" >/dev/null
}
[ -f "$ISCC" ] || ISCC="/c/Program Files (x86)/Inno Setup 6/ISCC.exe"

gh auth status >/dev/null 2>&1 || { echo "Connexion GitHub requise : gh auth login"; exit 1; }
if [ -n "${OPTIFIN_SIGN_SHA1:-}" ]; then
  [ -n "$SIGNTOOL" ] || { echo "signtool introuvable (Windows SDK)"; exit 1; }
  echo "Signature avec le certificat $OPTIFIN_SIGN_SHA1"
else
  echo "Aucun certificat de signature (OPTIFIN_SIGN_SHA1) : version NON signée, Windows affichera « Éditeur inconnu »."
fi
[ -z "$(git status --porcelain -- .)" ] || { echo "Modifications non validées dans windows-native/ : commit d'abord."; exit 1; }

# Numéro suivant : le plus grand windows-N publié + 1 (version 1.1.N, toujours croissante).
LAST=$(gh release list --limit 100 --json tagName --jq '.[].tagName' | grep '^windows-' | sed 's/windows-//' | sort -n | tail -1)
N=$(( ${LAST:-0} + 1 ))
VERSION="1.1.$N"
TAG="windows-$N"
echo "Publication de OptiFin Windows $VERSION ($TAG)"

dotnet test --project tests/OptiFin.Core.Tests -c Release
rm -rf out/x64 out/installer
dotnet publish src/OptiFin.App/OptiFin.App.csproj -c Release -r win-x64 -p:Platform=x64 -p:Version="$VERSION" -o out/x64
sign out/x64/OptiFin.exe
"$ISCC" //Q //DAppVersion="$VERSION" installer/optifin.iss
sign out/installer/OptiFin-windows-setup.exe

DIST=$(mktemp -d)
cp out/installer/OptiFin-windows-setup.exe "$DIST/"
MOBILE=$(gh release list --limit 50 --json tagName --jq '.[].tagName' | grep '^build-' | sort -t- -k2 -n -r | head -1 || true)
[ -n "$MOBILE" ] && gh release download "$MOBILE" --dir "$DIST" --pattern 'OptiFin.ipa' --pattern 'OptiFin-android-*.apk' --pattern 'source.json' || true

gh release create "$TAG" "$DIST"/* --draft --target "$(git rev-parse HEAD)" \
  --title "OptiFin Windows $VERSION" --notes "$(git log -1 --pretty=%B)"
gh release edit "$TAG" --draft=false --latest
rm -rf "$DIST"

# Ne garder que les 5 dernières versions PC.
gh release list --limit 100 --json tagName --jq '.[].tagName' | grep '^windows-' | sort -t- -k2 -n -r | tail -n +6 | \
  xargs -r -I{} gh release delete {} --yes --cleanup-tag
echo "Publié : OptiFin Windows $VERSION"
