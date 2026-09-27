#!/usr/bin/env bash
# Version affichée de la build CI : <majeur>.<mineur> de pubspec.yaml + numéro d'exécution CI.
# Ex. pubspec 1.0.0 et exécution 9 -> 1.0.9. Toujours croissante, donc vue comme une mise à jour.
set -euo pipefail
base=$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//' | cut -d. -f1-2)
echo "${base}.${GITHUB_RUN_NUMBER:?GITHUB_RUN_NUMBER manquant}"
