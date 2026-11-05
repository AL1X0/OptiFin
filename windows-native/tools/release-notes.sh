#!/usr/bin/env bash
# Nouveautés d'une version, tirées de windows-native/CHANGELOG.md. Échoue si la section manque ou est vide.
#
#   bash windows-native/tools/release-notes.sh 1.1.20
set -euo pipefail
cd "$(dirname "$0")/.."
NOTES=$(awk -v v="## $1" '$0 == v { on = 1; next } /^## / { on = 0 } on' CHANGELOG.md | tr -d '\r' | sed '/^$/d')
[ -n "$NOTES" ] || { echo "windows-native/CHANGELOG.md : section « ## $1 » absente ou vide." >&2; exit 1; }
[ "${#NOTES}" -le 1500 ] || { echo "windows-native/CHANGELOG.md : nouveautés de $1 trop longues (${#NOTES} caractères, le Store en accepte 1500)." >&2; exit 1; }
printf '%s\n' "$NOTES"
