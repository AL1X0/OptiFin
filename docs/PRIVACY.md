# OptiFin — politique de confidentialité

*Dernière mise à jour : 5 octobre 2026*

OptiFin est un lecteur pour serveurs [Jellyfin](https://jellyfin.org). Il ne possède aucun serveur, aucun compte
et aucun service en ligne qui lui soit propre.

## Données collectées

**Aucune.** OptiFin ne collecte, ne vend et ne partage aucune donnée personnelle. Il n'intègre ni publicité, ni
mesure d'audience, ni outil de suivi, ni rapport de plantage envoyé à un tiers.

## Échanges réseau

- **Votre serveur Jellyfin** : OptiFin s'y connecte avec l'adresse et le compte que vous saisissez, pour afficher
  vos bibliothèques, lire vos médias et enregistrer votre progression. Ces données restent entre l'appli et votre
  serveur. Les soirées à plusieurs (SyncPlay) passent elles aussi par votre serveur.
- **Recherche de sous-titres** : quand vous la demandez, elle est faite par votre serveur Jellyfin, avec les
  fournisseurs qui y sont configurés.
- **Mises à jour** (versions installées hors Microsoft Store) : l'appli consulte la liste publique des versions
  sur GitHub (`api.github.com`). Aucune donnée personnelle n'est envoyée. La version Microsoft Store est mise à
  jour par le Store.

## Données enregistrées sur l'appareil

- L'adresse des serveurs, le nom des comptes et les réglages de l'appli.
- Le jeton de connexion fourni par votre serveur, chiffré par le système (DPAPI sous Windows, Keystore sous
  Android, Trousseau sous iOS). Le mot de passe n'est jamais enregistré.
- Un journal technique local, consultable dans les réglages. Il n'est envoyé que si vous le demandez, et
  uniquement à votre propre serveur Jellyfin.

Désinstaller l'appli ou se déconnecter supprime ces données.

## Enfants

OptiFin ne s'adresse pas spécifiquement aux enfants et ne collecte aucune donnée les concernant.

## Contact

Questions ou demandes : [ouvrir un ticket sur GitHub](https://github.com/AL1X0/OptiFin/issues).
