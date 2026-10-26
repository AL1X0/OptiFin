#!/usr/bin/env bash
# Vérifie le lecteur Windows sur un binaire compilé (celui qui sera livré), contre le serveur de
# démonstration : lecteur sans barre de titre, plein écran qui couvre l'écran, retour à la place et
# à l'état d'avant (fenêtre normale ou agrandie), bouton dans la barre des tâches à chaque étape,
# touches Alt / Windows surveillées, une seule OptiFin à la fois. Code de sortie ≠ 0 au moindre échec.
#
#   bash windows-native/tools/check-player/check-player.sh [chemin/OptiFin.exe]
#
# Ferme toute OptiFin ouverte. Nécessite une session Windows avec barre des tâches.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
EXE=$(realpath -m "$(cygpath -u "${1:-$HERE/../../out/x64/OptiFin.exe}")")
cd "$HERE"
[ -f "$EXE" ] || { echo "Binaire introuvable : $EXE"; exit 2; }
export PATH="/c/Program Files/dotnet:$PATH"
DATA="$LOCALAPPDATA/OptiFin"
LOG="$DATA/optifin.log"
PLACEMENT="$DATA/window.txt"
PORT=8097
CAP=$(mktemp -d)
CAPW=$(cygpath -w "$CAP")
TITLE="Horizon perdu"
probe() { powershell -NoProfile -ExecutionPolicy Bypass -File probe.ps1 "$@" | tr -d '\r'; }
fails=0
expect() { if [ "$2" = "$3" ]; then echo "  OK     $1"; else echo "  ÉCHEC  $1 : « $2 », attendu « $3 »"; fails=$((fails + 1)); fi; }
stop_app() { taskkill //IM OptiFin.exe //F >/dev/null 2>&1; sleep 1; }
# Attend la capture d'une étape (prise 2,5 s après son action).
step() { for _ in $(seq 1 160); do [ -f "$CAP/$1.png" ] && return 0; sleep 0.25; done; echo "  ÉCHEC  étape « $1 » jamais atteinte"; fails=$((fails + 1)); return 1; }

# Serveur de démonstration (lancé ici s'il ne tourne pas déjà).
SERVER_PID=""
if ! curl -s -m 2 "http://localhost:$PORT/System/Info/Public" >/dev/null; then
  dotnet run --project ../OptiFin.DemoServer -- $PORT >/dev/null 2>&1 &
  SERVER_PID=$!
  for _ in $(seq 1 120); do curl -s -m 1 "http://localhost:$PORT/System/Info/Public" >/dev/null && break; sleep 0.5; done
fi
[ -f "$PLACEMENT" ] && cp "$PLACEMENT" "$CAP/window.bak"
cleanup() {
  stop_app
  if [ -f "$CAP/window.bak" ]; then cp "$CAP/window.bak" "$PLACEMENT"; else rm -f "$PLACEMENT"; fi
  [ -n "$SERVER_PID" ] && { kill "$SERVER_PID" 2>/dev/null; taskkill //IM OptiFin.DemoServer.exe //F >/dev/null 2>&1; }
  rm -rf "$CAP"
}
trap cleanup EXIT

SCREEN=$(probe screen)
scenario() {
  local name=$1 placement=$2 maximized=$3
  echo "== Lecteur, fenêtre principale $name"
  stop_app
  printf "%s" "$placement" > "$PLACEMENT"
  rm -f "$CAP"/*.png
  "$EXE" --capture "$CAPW" "c=demo:http://localhost:$PORT" l=lecture:horizon w1=3000 f=pleinecran w2=6000 f2=pleinecran w=20000 &
  step l || return
  sleep 1
  IFS=';' read -r before style cloak <<<"$(probe window "$TITLE")"
  expect "lecteur ouvert" "$([ -n "$style" ] && echo oui || echo non)" "oui"
  [ -n "$style" ] || return
  expect "lecteur sans barre de titre" "$(( (0x$style & 0xC00000) == 0xC00000 ? 1 : 0 ))" "0"
  expect "lecteur agrandi comme la fenêtre principale" "$(( (0x$style & 0x1000000) != 0 ? 1 : 0 ))" "$maximized"
  [ "$maximized" = 0 ] && expect "lecteur à la place de la fenêtre principale" "$before" "$(echo "$placement" | cut -d';' -f1-4 | tr ';' ',')"
  expect "bouton dans la barre des tâches (fenêtré)" "$(probe taskbar)" "oui"
  step f || return
  IFS=';' read -r rect style cloak <<<"$(probe window "$TITLE")"
  expect "plein écran : couvre tout l'écran" "$rect" "$SCREEN"
  expect "bouton dans la barre des tâches (plein écran)" "$(probe taskbar)" "oui"
  step f2 || return
  IFS=';' read -r rect style cloak <<<"$(probe window "$TITLE")"
  expect "sortie du plein écran : place d'avant" "$rect" "$before"
  expect "sortie du plein écran : agrandi comme avant" "$(( (0x$style & 0x1000000) != 0 ? 1 : 0 ))" "$maximized"
  expect "bouton dans la barre des tâches (après)" "$(probe taskbar)" "oui"
  expect "journal : touches Alt / Windows surveillées" "$(grep -ac 'Touches Alt / Windows surveillées' "$LOG")" "1"
  expect "journal : aucune erreur de l'appli" "$(grep -aE ' [EW]/(app|player|home|capture)' "$LOG" | grep -vc 'mpv')" "0"
}
scenario "normale" "240;126;1440;900;0" 0
scenario "agrandie" "240;126;1440;900;1" 1

echo "== Instance unique"
stop_app
"$EXE" & sleep 4
for _ in 1 2 3 4; do "$EXE" & done
sleep 5
expect "une seule OptiFin après 5 lancements" "$(tasklist | grep -c '^OptiFin.exe')" "1"

echo "== $fails échec(s)"
[ "$fails" = 0 ]
