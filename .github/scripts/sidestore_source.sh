#!/usr/bin/env bash
# Génère la source SideStore / AltStore (format « source v2 ») pour une version publiée.
# Usage : sidestore_source.sh <ipa> <version> <build> <tag> <notes> > source.json
set -euo pipefail

IPA="$1"; VERSION="$2"; BUILD="$3"; TAG="$4"; NOTES="$5"
REPO="${GITHUB_REPOSITORY:-AL1X0/OptiFin}"
SIZE=$(stat -c%s "$IPA")
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
RAW="https://raw.githubusercontent.com/${REPO}/main"

jq -n \
  --arg version "$VERSION" --arg build "$BUILD" --arg date "$DATE" --arg notes "$NOTES" \
  --arg url "https://github.com/${REPO}/releases/download/${TAG}/OptiFin.ipa" \
  --arg icon "${RAW}/assets/branding/icon_1024.png" \
  --arg site "https://github.com/${REPO}" \
  --argjson size "$SIZE" \
'{
  name: "OptiFin",
  identifier: "app.optifin.source",
  subtitle: "Client Jellyfin premium",
  description: "Builds de test d’OptiFin, publiés automatiquement à chaque modification.",
  iconURL: $icon,
  website: $site,
  tintColor: "#000000",
  featuredApps: ["app.optifin.optifin"],
  apps: [{
    name: "OptiFin",
    bundleIdentifier: "app.optifin.optifin",
    developerName: "OptiFin",
    subtitle: "Films, séries et musique depuis votre serveur Jellyfin",
    localizedDescription: "Client Jellyfin immersif : lecture directe (libmpv), sous-titres ASS/PGS, reprise synchronisée, multi-comptes.",
    iconURL: $icon,
    tintColor: "#000000",
    category: "entertainment",
    screenshots: [],
    versions: [{
      version: $version,
      buildVersion: $build,
      date: $date,
      localizedDescription: $notes,
      downloadURL: $url,
      size: $size,
      minOSVersion: "15.0"
    }],
    appPermissions: {
      entitlements: [],
      privacy: {
        NSLocalNetworkUsageDescription: "OptiFin recherche les serveurs Jellyfin présents sur votre réseau local."
      }
    }
  }],
  news: []
}'
