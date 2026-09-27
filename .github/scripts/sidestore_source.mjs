// Génère la source SideStore / AltStore (format « source v2 ») pour une version publiée.
// Usage : node sidestore_source.mjs <ipa> <version> <build> <tag> <notes> > source.json
import { statSync } from 'node:fs';

const [ipa, version, build, tag, notes] = process.argv.slice(2);
if (!ipa || !version || !build || !tag) {
  console.error('Usage : sidestore_source.mjs <ipa> <version> <build> <tag> <notes>');
  process.exit(1);
}

const repo = process.env.GITHUB_REPOSITORY ?? 'AL1X0/OptiFin';
const raw = `https://raw.githubusercontent.com/${repo}/main`;
const icon = `${raw}/assets/branding/icon_1024.png`;

const source = {
  name: 'OptiFin',
  identifier: 'app.optifin.source',
  subtitle: 'Client Jellyfin premium',
  description: 'Builds de test d’OptiFin, publiés automatiquement à chaque modification.',
  iconURL: icon,
  website: `https://github.com/${repo}`,
  tintColor: '#000000',
  featuredApps: ['app.optifin.optifin'],
  apps: [
    {
      name: 'OptiFin',
      bundleIdentifier: 'app.optifin.optifin',
      developerName: 'OptiFin',
      subtitle: 'Films, séries et musique depuis votre serveur Jellyfin',
      localizedDescription:
        'Client Jellyfin immersif : lecture directe (libmpv), sous-titres ASS/PGS, reprise synchronisée, multi-comptes.',
      iconURL: icon,
      tintColor: '#000000',
      category: 'entertainment',
      screenshots: [],
      versions: [
        {
          version,
          buildVersion: String(build),
          date: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
          localizedDescription: notes || `Build ${build}`,
          downloadURL: `https://github.com/${repo}/releases/download/${tag}/OptiFin.ipa`,
          size: statSync(ipa).size,
          minOSVersion: '15.0',
        },
      ],
      appPermissions: {
        entitlements: [],
        privacy: {
          NSLocalNetworkUsageDescription: 'OptiFin recherche les serveurs Jellyfin présents sur votre réseau local.',
        },
      },
    },
  ],
  news: [],
};

process.stdout.write(JSON.stringify(source, null, 2) + '\n');
