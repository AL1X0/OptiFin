/// Traductions anglaises, par phrase française.
const englishTexts = <String, String>{
  // Navigation et composants
  'Accueil': 'Home', 'Bibliothèques': 'Libraries', 'Recherche': 'Search', 'Téléchargements': 'Downloads',
  'Vu': 'Watched', 'Chargement': 'Loading', 'Tout voir': 'See all', 'Retour': 'Back', 'Retour à {0}': 'Back to {0}', '{0} % regardé': '{0}% watched',
  'Élément introuvable': 'Item not found', 'Spécial': 'Special', 'Spécial {0}': 'Special {0}', '{0} saison': '{0} season', '{0} saisons': '{0} seasons', '{0} restantes': '{0} left',

  // Erreurs du serveur
  'Serveur injoignable. Vérifiez l’adresse et votre connexion.': 'Server unreachable. Check the address and your connection.',
  'Le serveur met trop de temps à répondre.': 'The server is taking too long to respond.', 'Certificat HTTPS invalide pour ce serveur.': 'Invalid HTTPS certificate for this server.',
  'Identifiant ou mot de passe incorrect.': 'Incorrect username or password.', 'Accès refusé par le serveur.': 'Access denied by the server.',
  'Erreur du serveur ({0}). Réessayez plus tard.': 'Server error ({0}). Try again later.', 'Cette adresse ne correspond pas à un serveur Jellyfin.': 'This address is not a Jellyfin server.',
  'Jellyfin {0} n’est pas pris en charge (10.9 minimum).': 'Jellyfin {0} is not supported (10.9 minimum).', 'Quick Connect est désactivé sur ce serveur.': 'Quick Connect is disabled on this server.',
  'Une erreur inattendue est survenue.': 'An unexpected error occurred.',
  'La lecture de ce contenu n’est pas autorisée pour votre compte.': 'Your account is not allowed to play this content.',
  'Aucun flux compatible : le serveur ne peut pas préparer ce fichier.': 'No compatible stream: the server cannot prepare this file.',
  'Limite de débit du serveur atteinte. Réessayez plus tard.': 'Server bitrate limit reached. Try again later.', 'Le serveur a refusé la lecture ({0}).': 'The server refused playback ({0}).',

  // Connexion et comptes
  'Comptes': 'Accounts', 'Paramètres': 'Settings', 'Ajouter un compte': 'Add an account', 'Se déconnecter': 'Sign out', 'Changer de compte, connecté en tant que {0}': 'Switch account, signed in as {0}',
  'Saisissez l’adresse de votre serveur.': 'Enter your server address.', 'Le serveur de démonstration ne répond pas. Réessayez plus tard.': 'The demo server is not responding. Try again later.',
  'Fermer': 'Close', 'Connectez-vous à votre serveur Jellyfin.': 'Connect to your Jellyfin server.', 'Sur ce réseau': 'On this network', 'Relancer la recherche': 'Search again',
  'Aucun serveur détecté automatiquement.': 'No server detected automatically.', 'Adresse du serveur': 'Server address', 'Continuer': 'Continue', 'Essayer avec le serveur de démonstration': 'Try with the demo server',
  'Saisissez votre nom d’utilisateur.': 'Enter your username.', 'Nom d’utilisateur': 'Username', 'Mot de passe': 'Password', 'Se connecter': 'Sign in', 'Utiliser Quick Connect': 'Use Quick Connect',
  'Le code a expiré. Réessayez.': 'The code has expired. Try again.', 'Sur un appareil déjà connecté, ouvrez Jellyfin › Profil › Quick Connect et saisissez ce code.': 'On a device already signed in, open Jellyfin › Profile › Quick Connect and enter this code.',
  'Code {0}': 'Code {0}', 'En attente d’autorisation…': 'Waiting for approval…',

  // Fiches
  '{0} épisode non vu': '{0} unwatched episode', '{0} épisodes non vus': '{0} unwatched episodes', 'Réessayer': 'Try again', 'Épisodes': 'Episodes',
  'Télécharger la saison ({0} épisode)': 'Download season ({0} episode)', 'Télécharger la saison ({0} épisodes)': 'Download season ({0} episodes)', 'Impossible de charger les épisodes.': 'Could not load the episodes.',
  'Contenu': 'Contents', 'Dans cette collection': 'In this collection', 'Distribution': 'Cast', 'Titres similaires': 'More like this', 'Informations techniques': 'Technical info', 'Vidéo': 'Video',
  '+ {0} autres pistes': '+ {0} more tracks', 'Impossible d’afficher cet élément.': 'Could not display this item.', 'Reprendre': 'Resume', 'Lecture': 'Play', 'Lecture ': 'Playback', 'Lire depuis le début': 'Play from the beginning',
  'Marquer comme non vu': 'Mark as unwatched', 'Marquer comme vu': 'Mark as watched', 'Retirer des favoris': 'Remove from favorites', 'Ajouter aux favoris': 'Add to favorites', 'Voir la série': 'View series',
  'Réalisation': 'Directed by', 'Scénario': 'Written by', 'Moins': 'Less', 'Plus': 'More',

  // Téléchargements
  'Connexion requise': 'Sign-in required', 'Fichier non téléchargeable': 'This file cannot be downloaded', 'En attente': 'Queued', 'Téléchargement': 'Downloading', 'En pause': 'Paused', 'Téléchargé': 'Downloaded', 'Échec': 'Failed',
  'Téléchargement lancé.': 'Download started.', 'Téléchargement lancé (Wi-Fi uniquement).': 'Download started (Wi-Fi only).', '{0} épisodes ajoutés aux téléchargements.': '{0} episodes added to downloads.',
  'Téléchargement impossible : {0}': 'Download failed: {0}', 'Télécharger': 'Download', 'Téléchargement en attente': 'Download queued', 'Téléchargement en cours': 'Downloading', 'Téléchargement en pause': 'Download paused',
  'Échec du téléchargement': 'Download failed', 'Mettre en pause': 'Pause', 'Supprimer le téléchargement': 'Delete download', 'Annuler le téléchargement': 'Cancel download', 'Tout supprimer': 'Delete all',
  'Impossible de lire les téléchargements.': 'Could not read downloads.', 'Tout supprimer ?': 'Delete all?', 'Tous les films et épisodes téléchargés seront effacés de cet appareil.': 'All downloaded movies and episodes will be removed from this device.',
  'Annuler': 'Cancel', 'Supprimer': 'Delete', 'Aucun téléchargement': 'No downloads',
  'Appuyez sur le bouton de téléchargement d’un film ou d’un épisode pour le regarder ': 'Tap the download button on a movie or an episode to watch it ', 'sans connexion, en avion ou en déplacement.': 'offline, on a plane or on the go.',
  '{0} film': '{0} movie', '{0} films': '{0} movies', '{0} série': '{0} show', '{0} séries': '{0} shows', '{0} en cours': '{0} in progress', '{0} épisode  ·  {1}': '{0} episode  ·  {1}', '{0} épisodes  ·  {1}': '{0} episodes  ·  {1}', 'Supprimer la série': 'Delete show', 'Lire': 'Play',

  // Accueil, bibliothèques, recherche
  'À suivre': 'Next up', 'Ajouts récents · {0}': 'Recently added · {0}', 'Favoris': 'Favorites', 'Infos': 'Info', 'Impossible de charger l’accueil.': 'Could not load the home page.',
  'Votre serveur ne contient encore rien à afficher.': 'Your server has nothing to show yet.', 'Titre': 'Title', 'Date d’ajout': 'Date added', 'Date de sortie': 'Release date', 'Note': 'Rating', 'Durée': 'Runtime', 'Année': 'Year',
  'Chromecast': 'Chromecast', 'Connexion à {0}…': 'Connecting to {0}…', 'Connexion à {0} impossible.': 'Could not connect to {0}.', 'Le Chromecast n’a pas pu lire ce titre.': 'The Chromecast could not play this title.',
  'Lire sur…': 'Play on…', 'Aucun autre appareil disponible. Ouvrez OptiFin ou Jellyfin sur l’autre écran, puis réessayez.': 'No other device available. Open OptiFin or Jellyfin on the other screen, then try again.',
  'Reculer de 10 s': 'Back 10 s', 'Avancer de 10 s': 'Forward 10 s', 'Lecture / pause': 'Play / pause', 'Arrêter': 'Stop', 'Sur {0}': 'On {0}',
  'Surprends-moi': 'Surprise me', 'Peu importe la durée': 'Any length', 'Moins de 1 h 30': 'Under 1 h 30', 'Moins de 2 h': 'Under 2 h',
  'Tous les genres': 'All genres', 'Voir la fiche': 'View details', 'Encore': 'Another one', 'Aucun titre ne correspond.': 'No matching title.',
  'Aucune bibliothèque.': 'No libraries.', 'Impossible de charger les bibliothèques.': 'Could not load libraries.', 'Trier et filtrer': 'Sort and filter', 'Réinitialiser': 'Reset', 'Trier par': 'Sort by', 'Croissant': 'Ascending', 'Décroissant': 'Descending',
  'Statut': 'Status', 'Tous': 'All', 'Non vus': 'Unwatched', 'Vus': 'Watched', 'Résolution': 'Resolution', 'Toutes': 'All', 'Années': 'Years', 'Bibliothèque indisponible.': 'Library unavailable.', 'Impossible de charger le contenu.': 'Could not load the content.',
  'Aucun résultat avec ces filtres.': 'No results with these filters.', 'Cette bibliothèque est vide.': 'This library is empty.', '{0} élément': '{0} item', '{0} éléments': '{0} items', 'Affichage grille': 'Grid view', 'Affichage liste': 'List view', 'Index alphabétique': 'Alphabetical index',
  'Né(e) en {0}': 'Born in {0}', 'Personne introuvable.': 'Person not found.', 'Filmographie': 'Filmography', 'Aucun titre dans votre bibliothèque.': 'No titles in your library.', 'Impossible de charger la filmographie.': 'Could not load the filmography.',
  'Films, séries, personnes, musique…': 'Movies, shows, people, music…', 'Effacer': 'Clear', 'Recherchez dans toutes vos bibliothèques.': 'Search all your libraries.', 'Aucun résultat pour « {0} ».': 'No results for “{0}”.', 'La recherche a échoué.': 'Search failed.',
  'Films': 'Movies', 'Séries': 'Shows', 'Collections et vidéos': 'Collections and videos', 'Artistes': 'Artists', 'Morceaux': 'Tracks', 'Personnes': 'People',

  // Lecteur
  'Sous-titre {0}': 'Subtitle {0}', 'Chapitre {0}': 'Chapter {0}', 'Piste {0}': 'Track {0}', 'Natif': 'Native', 'Lecture directe': 'Direct play', 'Transcodage': 'Transcoding', 'Automatique': 'Automatic', 'Incruster (serveur)': 'Burn in (server)',
  'Passer l’intro': 'Skip intro', 'Passer le récapitulatif': 'Skip recap', 'Passer l’aperçu': 'Skip preview', 'Passer la publicité': 'Skip ad', 'Passer le générique': 'Skip credits', 'Synchro exacte': 'Exact sync', 'Malentendants': 'Hearing impaired', 'Forcés': 'Forced', '{0} téléchargements': '{0} downloads',
  'Le serveur n’a pas encore ajouté ce sous-titre. Réessayez.': 'The server has not added this subtitle yet. Try again.', 'Le lecteur n’a pas pu lire ce fichier.': 'The player could not play this file.', 'Bascule vers {0}…': 'Switching to {0}…', 'La lecture n’a pas pu démarrer.': 'Playback could not start.',
  'Désactivés': 'Off', 'Chapitres': 'Chapters', 'Vitesse': 'Speed', 'Synchronisation': 'Sync', 'Aucun décalage': 'No offset', 'Ajustée': 'Adjusted', 'Moteur de lecture': 'Playback engine', 'Verrouiller l’écran': 'Lock screen', 'Infos techniques': 'Technical info',
  'Rechercher en ligne…': 'Search online…', 'Apparence': 'Appearance', 'Apparence des sous-titres': 'Subtitle appearance', 'Taille': 'Size', 'Fond': 'Background', 'Contour': 'Outline', 'Ombre': 'Shadow', 'Bandeau': 'Box', 'Décalage des sous-titres': 'Subtitle offset',
  'Positif : les sous-titres apparaissent plus tard.': 'Positive: subtitles appear later.', 'Décalage audio': 'Audio offset', 'Positif : le son est retardé.': 'Positive: audio is delayed.', 'Le meilleur moteur pour chaque fichier': 'The best engine for each file',
  'Lit presque tout, sous-titres stylés': 'Plays almost anything, styled subtitles', 'En cours : {0} · {1}': 'Current: {0} · {1}', 'Normale': 'Normal', 'Petite': 'Small', 'Grande': 'Large', 'Très grande': 'Very large', 'Par défaut': 'Default', 'Externe': 'External', 'Image': 'Image',
  'Épisode suivant : {0}': 'Next episode: {0}', 'ÉPISODE SUIVANT': 'NEXT EPISODE', 'Lecture dans {0} s': 'Playing in {0} s', 'Continuer le générique': 'Keep watching the credits', 'Téléchargement impossible.': 'Download failed.', 'Rechercher des sous-titres': 'Search for subtitles',
  'Recherche impossible.': 'Search failed.', 'Aucun sous-titre trouvé. Un fournisseur (ex. OpenSubtitles) doit être installé sur le serveur.': 'No subtitles found. A provider (e.g. OpenSubtitles) must be installed on the server.', 'Erreur de lecture.': 'Playback error.', 'Journaux': 'Logs',
  'Fermer le lecteur': 'Close player', 'Picture-in-Picture indisponible pour cette lecture.': 'Picture-in-Picture is unavailable for this video.', 'Déverrouiller': 'Unlock', 'Zoomer (remplir l’écran)': 'Zoom (fill the screen)', 'Étirer à l’écran': 'Stretch to screen', 'Format d’origine': 'Original format',
  'Réglages': 'Settings', 'Reculer de 10 secondes': 'Back 10 seconds', 'Pause': 'Pause', 'Avancer de 10 secondes': 'Forward 10 seconds', 'Position de lecture': 'Playback position', 'Moteur': 'Engine', 'Décision': 'Decision', 'Raison': 'Reason', 'Conteneur': 'Container', 'Débit': 'Bitrate',
  'Aucun': 'None', 'Tampon': 'Buffer', 'Images perdues': 'Dropped frames', 'Moins 0,1 s': 'Minus 0.1 s', 'Plus 0,1 s': 'Plus 0.1 s',

  // Réglages
  'Réglage du serveur': 'Server setting', 'Toujours': 'Always', 'Forcés uniquement': 'Forced only', 'Jamais': 'Never', 'Français': 'French', 'Anglais': 'English', 'Espagnol': 'Spanish', 'Allemand': 'German', 'Italien': 'Italian', 'Portugais': 'Portuguese', 'Japonais': 'Japanese', 'Coréen': 'Korean',
  'Chinois': 'Chinese', 'Russe': 'Russian', 'Arabe': 'Arabic', 'Néerlandais': 'Dutch', '(journal vide)': '(empty log)', '{0} lignes copiées dans le presse-papiers': '{0} lines copied to the clipboard', 'Envoyé au serveur : {0} (Tableau de bord › Journaux)': 'Sent to the server: {0} (Dashboard › Logs)',
  'Envoi impossible (serveur hors ligne ou envoi désactivé).': 'Could not send (server offline or sending disabled).', 'Envoyer au serveur': 'Send to server', 'Tout copier': 'Copy all', 'Tout': 'All', 'Avertissements': 'Warnings', 'Erreurs': 'Errors', 'Journal vide.': 'Empty log.',
  'Journal vide. Activez le mode debug pour plus de détails.': 'Empty log. Turn on debug mode for more details.', 'Copier': 'Copy', 'Choix du serveur': 'Server choice', 'Qualité maximale en Wi-Fi': 'Maximum quality on Wi-Fi', 'Qualité maximale en cellulaire': 'Maximum quality on cellular',
  'Automatique (recommandé)': 'Automatic (recommended)', 'Natif (AVPlayer / Media3)': 'Native (AVPlayer / Media3)', 'Automatique : le meilleur moteur pour chaque fichier': 'Automatic: the best engine for each file', 'Natif : HDR, Dolby Vision, économie de batterie': 'Native: HDR, Dolby Vision, saves battery',
  'mpv : lit tout, sous-titres ASS fidèles': 'mpv: plays everything, accurate ASS subtitles', 'Sous-titres image (PGS) sur du HDR': 'Image subtitles (PGS) on HDR', 'Rendus par mpv': 'Rendered by mpv', 'Incrustés par le serveur': 'Burned in by the server',
  'Sous-titres image sur une vidéo HDR / Dolby Vision': 'Image subtitles on HDR / Dolby Vision video', 'Rendus par mpv (aucune charge serveur)': 'Rendered by mpv (no server load)', 'Incrustés par le serveur (garde le lecteur natif)': 'Burned in by the server (keeps the native player)', 'Langues': 'Languages',
  'Langue audio préférée': 'Preferred audio language', 'Sous-titres au démarrage': 'Subtitles at start', 'Langue des sous-titres': 'Subtitle language', 'Passer les intros automatiquement': 'Skip intros automatically',
  'Intros, récapitulatifs et aperçus détectés par le serveur (sinon, un bouton « Passer »).': 'Intros, recaps and previews detected by the server (otherwise, a “Skip” button).', 'Épisode suivant automatique': 'Autoplay next episode', 'Enchaîne après un compte à rebours de 10 s pendant le générique.': 'Continues after a 10 s countdown during the credits.',
  'Taille des sous-titres': 'Subtitle size', 'Fond des sous-titres': 'Subtitle background', 'Stockage': 'Storage', 'Télécharger en Wi-Fi uniquement': 'Download on Wi-Fi only', 'Les films et épisodes téléchargés attendent le Wi-Fi (pas de données mobiles).': 'Downloaded movies and episodes wait for Wi-Fi (no mobile data).',
  'Vider le cache des images': 'Clear image cache', 'Cache des images vidé.': 'Image cache cleared.', 'Compte': 'Account', 'Avancé': 'Advanced', 'Mode debug': 'Debug mode', 'Journaux détaillés (requêtes, lecteur, mpv) et infos techniques dans le lecteur.': 'Detailed logs (requests, player, mpv) and technical info in the player.',
  'Afficher, copier, effacer': 'View, copy, clear', 'Capacités de l’appareil': 'Device capabilities', 'À propos': 'About', 'Version {0}': 'Version {0}', 'Licences': 'Licenses',

  // Soirées
  'Soirée': 'Party', 'Vous ne faites plus partie de cette soirée.': 'You are no longer part of this party.', 'Cette soirée n’existe plus.': 'This party no longer exists.',
  'Votre compte n’a pas le droit de créer une soirée (réglage SyncPlay du serveur).': 'Your account is not allowed to create a party (server SyncPlay setting).', 'Votre compte n’a pas le droit de rejoindre une soirée (réglage SyncPlay du serveur).': 'Your account is not allowed to join a party (server SyncPlay setting).',
  'Un participant n’a pas accès à ce titre dans ses bibliothèques.': 'A participant does not have access to this title in their libraries.', 'Vous avez rejoint « {0} »': 'You joined “{0}”', 'Vous avez quitté la soirée': 'You left the party', '{0} a rejoint la soirée': '{0} joined the party', '{0} a quitté la soirée': '{0} left the party',
  'L’hôte a arrêté la lecture': 'The host stopped playback', 'La soirée n’a pas pu être mise à jour.': 'The party could not be updated.', 'Soirée : regarder ensemble': 'Watch party: watch together', 'Soirée {0}, {1} participants': 'Party {0}, {1} participants', 'Soirée de {0}': '{0}’s party',
  '{0} · en attente des autres…': '{0} · waiting for the others…', '{0} · {1} participant': '{0} · {1} participant', '{0} · {1} participants': '{0} · {1} participants', 'Lecture en cours': 'Now playing', 'En attente des participants…': 'Waiting for participants…',
  'Lancez un film ou un épisode : il démarre chez tout le monde, au même moment.': 'Start a movie or an episode: it begins for everyone at the same time.', 'Connexion au serveur interrompue, reconnexion…': 'Connection to the server lost, reconnecting…', 'PARTICIPANTS ({0})': 'PARTICIPANTS ({0})', 'Quitter la soirée': 'Leave the party',
  'Regardez un film à plusieurs, chacun chez soi : lecture, pause et avance sont synchronisées.': 'Watch a movie together from home: play, pause and seek stay in sync.', 'Nom de la soirée': 'Party name', 'Créer une soirée': 'Create a party', 'Connexion au serveur en cours…': 'Connecting to the server…', 'SOIRÉES EN COURS': 'CURRENT PARTIES',
  'Actualiser': 'Refresh', 'Aucune soirée pour le moment.': 'No parties right now.', 'Rejoindre': 'Join',
};
