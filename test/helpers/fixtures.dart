/// Fabriques de JSON Jellyfin (format serveur, PascalCase) pour les tests.
Map<String, Object?> dtoJson({
  required String id,
  String type = 'Movie',
  String? name,
  Map<String, Object?> extra = const {},
}) =>
    {
      'Id': id,
      'Name': name ?? 'Item $id',
      'Type': type,
      'MediaType': type == 'Episode' || type == 'Movie' ? 'Video' : 'Unknown',
      ...extra,
    };

Map<String, Object?> queryResult(List<Map<String, Object?>> items, {int? total}) => {
      'Items': items,
      'TotalRecordCount': total ?? items.length,
      'StartIndex': 0,
    };

Map<String, Object?> videoStream({int width = 3840, int height = 1600, String rangeType = 'HDR10', String codec = 'hevc'}) => {
      'Type': 'Video',
      'Codec': codec,
      'Width': width,
      'Height': height,
      'VideoRange': 'HDR',
      'VideoRangeType': rangeType,
      'AudioSpatialFormat': 'None',
      'Index': 0,
      'IsInterlaced': false,
      'IsDefault': true,
      'IsForced': false,
      'IsHearingImpaired': false,
      'IsOriginal': false,
      'IsExternal': false,
      'IsTextSubtitleStream': false,
      'SupportsExternalStream': false,
    };

Map<String, Object?> audioStream({String codec = 'truehd', int channels = 8, String spatial = 'DolbyAtmos', String? profile}) => {
      'Type': 'Audio',
      'Codec': codec,
      'Channels': channels,
      'Profile': ?profile,
      'VideoRange': 'Unknown',
      'VideoRangeType': 'Unknown',
      'AudioSpatialFormat': spatial,
      'Index': 1,
      'IsInterlaced': false,
      'IsDefault': true,
      'IsForced': false,
      'IsHearingImpaired': false,
      'IsOriginal': false,
      'IsExternal': false,
      'IsTextSubtitleStream': false,
      'SupportsExternalStream': false,
    };
