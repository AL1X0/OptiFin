/// Bibliothèque fictive pour la vidéo de démo et les captures du README.
///
/// Titres, résumés, personnes et visuels sont inventés : aucune œuvre réelle.
library;

import 'demo_artwork.dart';

class DemoPerson {
  const DemoPerson(this.id, this.name, this.hue);

  final String id;
  final String name;

  /// Teinte du portrait généré.
  final double hue;
}

const people = [
  DemoPerson('p-lea', 'Léa Marchand', 20),
  DemoPerson('p-samir', 'Samir Haddad', 200),
  DemoPerson('p-ines', 'Inès Morel', 320),
  DemoPerson('p-hugo', 'Hugo Vasseur', 150),
  DemoPerson('p-chloe', 'Chloé Nguyen', 45),
  DemoPerson('p-adrien', 'Adrien Kessler', 260),
  DemoPerson('p-camille', 'Camille Arnaud', 10),
];

class DemoTitle {
  const DemoTitle({
    required this.id,
    required this.name,
    required this.type,
    required this.scene,
    this.year = 2025,
    this.genres = const [],
    this.overview,
    this.tagline,
    this.minutes = 110,
    this.rating = 7.5,
    this.officialRating = '12',
    this.quality = DemoQuality.uhdDolbyVision,
    this.progress = 0,
    this.played = false,
    this.favorite = false,
    this.seriesId,
    this.seasonId,
    this.index,
    this.season,
    this.variant = 0,
    this.addedDaysAgo = 30,
  });

  final String id;
  final String name;

  /// Movie, Series, Season, Episode.
  final String type;
  final Scene scene;
  final int year;
  final List<String> genres;
  final String? overview;
  final String? tagline;
  final int minutes;
  final double rating;
  final String officialRating;
  final DemoQuality quality;

  /// Progression (0 = non commencé).
  final double progress;
  final bool played;
  final bool favorite;
  final String? seriesId;
  final String? seasonId;
  final int? index;
  final int? season;

  /// Variation de l'illustration (épisodes d'une même série).
  final int variant;
  final int addedDaysAgo;
}

enum DemoQuality { uhdDolbyVision, uhdHdr10, fullHd }

const movies = [
  DemoTitle(
    id: 'horizon',
    name: 'Horizon perdu',
    type: 'Movie',
    scene: Scene.dunes,
    genres: ['Science-fiction', 'Aventure'],
    minutes: 134,
    rating: 7.9,
    tagline: 'Deux soleils. Un seul retour possible.',
    overview:
        'Échouée sur une planète désertique après un saut raté, une pilote cartographe n’a que la '
        'course de deux soleils pour retrouver le signal de son vaisseau avant la grande nuit.',
    favorite: true,
    addedDaysAgo: 2,
  ),
  DemoTitle(
    id: 'marees',
    name: 'Les Marées d’Orion',
    type: 'Movie',
    scene: Scene.ocean,
    year: 2024,
    genres: ['Drame', 'Science-fiction'],
    minutes: 118,
    rating: 7.4,
    quality: DemoQuality.uhdHdr10,
    progress: 0.42,
    tagline: 'L’océan se souvient de tout.',
    overview:
        'Sur une station océanique isolée, une biologiste découvre que les marées suivent un motif '
        'qui n’a rien de naturel. Et qu’il semble lui répondre.',
    addedDaysAgo: 6,
  ),
  DemoTitle(
    id: 'neon',
    name: 'Ville néon',
    type: 'Movie',
    scene: Scene.city,
    genres: ['Thriller', 'Policier'],
    minutes: 122,
    rating: 7.1,
    officialRating: '16',
    tagline: 'La ville ne dort jamais. Elle observe.',
    overview:
        'Une inspectrice insomniaque traque un pirate capable d’éteindre des quartiers entiers '
        'd’une mégapole qui ne connaît plus l’obscurité.',
    addedDaysAgo: 1,
  ),
  DemoTitle(
    id: 'sommet',
    name: 'Le Dernier Sommet',
    type: 'Movie',
    scene: Scene.peaks,
    year: 2023,
    genres: ['Aventure', 'Drame'],
    minutes: 109,
    rating: 8.1,
    quality: DemoQuality.uhdHdr10,
    tagline: 'Certaines montagnes se méritent.',
    overview:
        'Trente ans après l’accident qui a coûté la vie à sa cordée, un alpiniste retourne affronter '
        'la face nord qu’il n’a jamais osé regarder à nouveau.',
    favorite: true,
    addedDaysAgo: 12,
  ),
  DemoTitle(
    id: 'brume',
    name: 'Brume',
    type: 'Movie',
    scene: Scene.forest,
    year: 2024,
    genres: ['Mystère', 'Thriller'],
    minutes: 101,
    rating: 6.9,
    quality: DemoQuality.fullHd,
    progress: 0.18,
    tagline: 'Ne quittez pas le sentier.',
    overview: 'Chaque automne, la forêt de Vaux engloutit un randonneur. Cette année, c’est le frère de Nina.',
    addedDaysAgo: 20,
  ),
  DemoTitle(
    id: 'nebuleuse',
    name: 'Nébuleuse',
    type: 'Movie',
    scene: Scene.nebula,
    genres: ['Science-fiction'],
    minutes: 146,
    rating: 8.3,
    tagline: 'Au-delà de la lumière, il y a nous.',
    overview:
        'L’équipage du Céleste a douze heures pour traverser une nébuleuse vivante qui réécrit la '
        'mémoire de tous ceux qui s’en approchent.',
    addedDaysAgo: 4,
  ),
  DemoTitle(
    id: 'minuit',
    name: 'Soleil de minuit',
    type: 'Movie',
    scene: Scene.arctic,
    year: 2022,
    genres: ['Drame', 'Romance'],
    minutes: 112,
    rating: 7.6,
    quality: DemoQuality.uhdHdr10,
    played: true,
    tagline: 'Un été sans nuit. Une rencontre sans fin.',
    overview: 'Au-delà du cercle polaire, deux inconnus partagent un été où le soleil ne se couche jamais.',
    addedDaysAgo: 60,
  ),
  DemoTitle(
    id: 'canyons',
    name: 'L’Écho des canyons',
    type: 'Movie',
    scene: Scene.canyon,
    year: 2023,
    genres: ['Western', 'Aventure'],
    minutes: 125,
    rating: 7.2,
    tagline: 'Le désert rend toujours ce qu’on lui prend.',
    overview: 'Une convoyeuse d’eau et un faussaire traversent les canyons rouges, poursuivis par une compagnie minière.',
    addedDaysAgo: 35,
  ),
  DemoTitle(
    id: 'aurore',
    name: 'Aurore boréale',
    type: 'Movie',
    scene: Scene.aurora,
    year: 2024,
    genres: ['Romance', 'Drame'],
    minutes: 104,
    rating: 6.8,
    quality: DemoQuality.fullHd,
    tagline: 'Le ciel a choisi pour eux.',
    overview: 'Une photographe et un guide inuit attendent l’aurore parfaite, au bout d’un hiver qui n’en finit pas.',
    addedDaysAgo: 45,
  ),
  DemoTitle(
    id: 'tempete',
    name: 'Avis de tempête',
    type: 'Movie',
    scene: Scene.storm,
    genres: ['Action', 'Thriller'],
    minutes: 117,
    rating: 6.6,
    officialRating: '12',
    tagline: 'Force 12. Aucun abri.',
    overview: 'Un pilote de sauvetage et son équipage ont une nuit pour évacuer une plateforme pétrolière dans l’œil du cyclone.',
    addedDaysAgo: 8,
  ),
];

const series = [
  DemoTitle(
    id: 'veilleurs',
    name: 'Les Veilleurs',
    type: 'Series',
    scene: Scene.aurora,
    year: 2024,
    genres: ['Science-fiction', 'Drame'],
    rating: 8.4,
    minutes: 48,
    variant: 3,
    tagline: 'Quelqu’un doit rester éveillé.',
    overview:
        'Dans un monde où plus personne ne rêve, cinq veilleurs de nuit découvrent que leurs rêves '
        'à eux commencent à se réaliser.',
    favorite: true,
    addedDaysAgo: 3,
  ),
  DemoTitle(
    id: 'kepler',
    name: 'Station Kepler',
    type: 'Series',
    scene: Scene.nebula,
    year: 2023,
    genres: ['Science-fiction', 'Thriller'],
    rating: 7.8,
    minutes: 52,
    variant: 5,
    tagline: 'À 1 400 années-lumière, personne ne vous entend mentir.',
    overview: 'Huis clos à bord d’une station minière en orbite d’une exoplanète, après la disparition de son commandant.',
    addedDaysAgo: 15,
  ),
  DemoTitle(
    id: 'rivages',
    name: 'Rivages',
    type: 'Series',
    scene: Scene.ocean,
    year: 2025,
    genres: ['Drame'],
    rating: 7.5,
    minutes: 45,
    variant: 2,
    quality: DemoQuality.uhdHdr10,
    tagline: 'Chaque vague ramène un secret.',
    overview: 'Sur une île bretonne, le retour d’une avocate parisienne réveille un naufrage vieux de vingt ans.',
    addedDaysAgo: 9,
  ),
];

const _episodeNames = {
  'veilleurs': [
    ['Nuit blanche', 'Le Premier Rêve', 'Insomnies', 'Phase paradoxale', 'Les Dormeurs', 'Réveil'],
    ['Somnambules', 'La Ville endormie', 'Veille', 'Mémoire vive', 'Le Rêve partagé', 'Aube'],
  ],
  'kepler': [
    ['Arrivée', 'Le Commandant', 'Dépressurisation', 'Orbite basse', 'Signal', 'Quarantaine', 'Éclipse', 'Retour'],
  ],
  'rivages': [
    ['Marée haute', 'Le Phare', 'L’Épave', 'Grande marée', 'Tempête', 'Rivages'],
  ],
};

/// Saisons et épisodes générés à partir des séries.
final seasons = [
  for (final s in series)
    for (final (i, _) in _episodeNames[s.id]!.indexed)
      DemoTitle(
        id: '${s.id}-s${i + 1}',
        name: 'Saison ${i + 1}',
        type: 'Season',
        scene: s.scene,
        year: s.year + i,
        seriesId: s.id,
        index: i + 1,
        variant: s.variant + i,
      ),
];

final episodes = [
  for (final s in series)
    for (final (si, names) in _episodeNames[s.id]!.indexed)
      for (final (ei, name) in names.indexed)
        DemoTitle(
          id: '${s.id}-s${si + 1}e${ei + 1}',
          name: name,
          type: 'Episode',
          scene: s.scene,
          year: s.year + si,
          minutes: s.minutes + (ei * 3) % 9,
          rating: s.rating,
          seriesId: s.id,
          seasonId: '${s.id}-s${si + 1}',
          season: si + 1,
          index: ei + 1,
          variant: s.variant * 7 + si * 13 + ei * 5 + 1,
          quality: s.quality,
          overview: _episodeOverview(s.id, si, ei),
          // Les Veilleurs : saison 1 vue, saison 2 en cours (épisode 3 commencé).
          played: s.id == 'veilleurs' && (si == 0 || ei < 2),
          progress: s.id == 'veilleurs' && si == 1 && ei == 2 ? 0.34 : 0,
        ),
];

String _episodeOverview(String series, int season, int episode) => switch (series) {
  'veilleurs' => 'Les veilleurs découvrent une nouvelle faille entre la veille et le rêve.',
  'kepler' => 'La tension monte à bord de la station alors que l’équipage cherche un coupable.',
  _ => 'Les secrets de l’île remontent à la surface avec la marée.',
};

final allTitles = [...movies, ...series, ...seasons, ...episodes];

DemoTitle titleById(String id) => allTitles.firstWhere((t) => t.id == id);
