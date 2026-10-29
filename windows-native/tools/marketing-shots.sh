#!/usr/bin/env bash
# Captures du Microsoft Store (1920 × 1080) sur le serveur Jellyfin de démonstration public :
# accueil, fiche film, série, bibliothèque, recherche → windows-native/store/screenshots/.
#
#   bash windows-native/tools/marketing-shots.sh
#
# À lancer sur un bureau Windows affiché (session ouverte, écran ≥ 1920 × 1080) : sans bureau
# visible, Windows ne dessine pas les images dans les captures. Ferme OptiFin ; les comptes et
# réglages de l'appli sont sauvegardés puis remis tels quels.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/c/Program Files/dotnet:/c/Program Files (x86)/Microsoft Visual Studio/Installer:$PATH"
DATA="$LOCALAPPDATA/OptiFin"
BACKUP=$(mktemp -d)
OUT=$(mktemp -d)

dotnet publish src/OptiFin.App/OptiFin.App.csproj -c Release -r win-x64 -p:Platform=x64 -o out/capture -nologo -v q
taskkill //IM OptiFin.exe //F >/dev/null 2>&1 || true
[ -d "$DATA" ] && cp -r "$DATA/." "$BACKUP/"
restore() { taskkill //IM OptiFin.exe //F >/dev/null 2>&1 || true; rm -rf "$DATA"; mkdir -p "$DATA"; cp -r "$BACKUP/." "$DATA/"; rm -rf "$BACKUP" "$OUT"; }
trap restore EXIT
rm -rf "$DATA"; mkdir -p "$DATA"
printf "0;0;1920;1080;0" > "$DATA/window.txt"

out/capture/OptiFin.exe --capture "$(cygpath -w "$OUT")" \
  "connexion=demo:https://demo.jellyfin.org/stable|demo" \
  1-accueil=8000 \
  2-fiche=fiche:5e6e8380563c5211106652362c5c6843 \
  3-serie=fiche:9bd5926326d651153928e0d11c6ee7cb \
  4-bibliotheque=bibliotheque:Movies \
  5-recherche=recherche:night
mkdir -p store/screenshots
rm -f store/screenshots/*.png
cp "$OUT"/[1-5]-*.png store/screenshots/
echo "Captures : windows-native/store/screenshots/"
