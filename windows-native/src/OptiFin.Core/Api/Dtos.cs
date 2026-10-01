using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace OptiFin.Core.Api;

// Sous-ensemble de l'API Jellyfin (10.9+) utilisé par OptiFin. Les noms suivent le JSON du
// serveur (PascalCase) ; les énumérations restent des chaînes (tolérance aux nouvelles valeurs).

public sealed class PublicSystemInfo
{
    public string? Id { get; set; }
    public string? ServerName { get; set; }
    public string? Version { get; set; }
    public string? ProductName { get; set; }
}

public sealed class UserDto
{
    public string Id { get; set; } = "";
    public string? Name { get; set; }
    public string? PrimaryImageTag { get; set; }
    public bool? HasPassword { get; set; }
}

public sealed class AuthenticationResult
{
    public UserDto? User { get; set; }
    public string? AccessToken { get; set; }
}

public sealed class QuickConnectResult
{
    public bool? Authenticated { get; set; }
    public string? Secret { get; set; }
    public string? Code { get; set; }
}

public sealed class NameGuidPair
{
    public string? Id { get; set; }
    public string? Name { get; set; }
}

public sealed class BaseItemPerson
{
    public string Id { get; set; } = "";
    public string? Name { get; set; }
    public string? Role { get; set; }
    public string? Type { get; set; }
    public string? PrimaryImageTag { get; set; }
}

public sealed class MediaUrl
{
    public string? Url { get; set; }
    public string? Name { get; set; }
}

public sealed class UserItemDataDto
{
    public bool? Played { get; set; }
    public bool? IsFavorite { get; set; }
    public long? PlaybackPositionTicks { get; set; }
    public double? PlayedPercentage { get; set; }
    public int? UnplayedItemCount { get; set; }
}

public sealed class ImageBlurHashes
{
    public Dictionary<string, string>? Primary { get; set; }
    public Dictionary<string, string>? Backdrop { get; set; }
    public Dictionary<string, string>? Logo { get; set; }
    public Dictionary<string, string>? Thumb { get; set; }
}

public sealed class ChapterInfo
{
    public long? StartPositionTicks { get; set; }
    public string? Name { get; set; }
    public string? ImageTag { get; set; }
}

public sealed class TrickplayInfoDto
{
    public int? Width { get; set; }
    public int? Height { get; set; }
    public int? TileWidth { get; set; }
    public int? TileHeight { get; set; }
    public int? ThumbnailCount { get; set; }
    public int? Interval { get; set; }
}

public sealed class MediaStream
{
    public string? Type { get; set; }
    public int? Index { get; set; }
    public string? Codec { get; set; }
    public string? Language { get; set; }
    public string? DisplayTitle { get; set; }
    public string? Title { get; set; }
    public int? Channels { get; set; }
    public bool? IsDefault { get; set; }
    public bool? IsForced { get; set; }
    public bool? IsExternal { get; set; }
    public bool? IsTextSubtitleStream { get; set; }
    public string? DeliveryUrl { get; set; }
    public int? Width { get; set; }
    public int? Height { get; set; }
    public int? BitDepth { get; set; }
    public string? VideoRangeType { get; set; }
    public string? Profile { get; set; }
    public string? AudioSpatialFormat { get; set; }
}

public sealed class MediaSourceInfo
{
    public string? Id { get; set; }
    public string? Container { get; set; }
    public long? Bitrate { get; set; }
    public long? RunTimeTicks { get; set; }
    public bool? SupportsDirectPlay { get; set; }
    public bool? SupportsDirectStream { get; set; }
    public string? TranscodingUrl { get; set; }
    public string? ETag { get; set; }
    public int? DefaultAudioStreamIndex { get; set; }
    public int? DefaultSubtitleStreamIndex { get; set; }
    public List<MediaStream>? MediaStreams { get; set; }
}

public sealed class BaseItemDto
{
    public string Id { get; set; } = "";
    public string? Name { get; set; }
    public string? Type { get; set; }
    public string? OriginalTitle { get; set; }
    public string? Overview { get; set; }
    public List<string>? Taglines { get; set; }
    public int? ProductionYear { get; set; }
    public DateTimeOffset? PremiereDate { get; set; }
    public DateTimeOffset? EndDate { get; set; }
    public string? Status { get; set; }
    public long? RunTimeTicks { get; set; }
    public long? CumulativeRunTimeTicks { get; set; }
    public float? CommunityRating { get; set; }
    public float? CriticRating { get; set; }
    public string? OfficialRating { get; set; }
    public List<NameGuidPair>? GenreItems { get; set; }
    public List<NameGuidPair>? Studios { get; set; }
    public List<BaseItemPerson>? People { get; set; }
    public List<MediaUrl>? RemoteTrailers { get; set; }
    public int? LocalTrailerCount { get; set; }
    public UserItemDataDto? UserData { get; set; }
    public string? SeriesId { get; set; }
    public string? SeriesName { get; set; }
    public string? SeasonId { get; set; }
    public string? SeasonName { get; set; }
    public int? IndexNumber { get; set; }
    public int? ParentIndexNumber { get; set; }
    public int? ChildCount { get; set; }
    public int? RecursiveItemCount { get; set; }
    public string? CollectionType { get; set; }
    public List<MediaSourceInfo>? MediaSources { get; set; }
    public List<MediaStream>? MediaStreams { get; set; }
    public Dictionary<string, string>? ImageTags { get; set; }
    public List<string>? BackdropImageTags { get; set; }
    public string? ParentBackdropItemId { get; set; }
    public List<string>? ParentBackdropImageTags { get; set; }
    public string? ParentLogoItemId { get; set; }
    public string? ParentLogoImageTag { get; set; }
    public string? ParentThumbItemId { get; set; }
    public string? ParentThumbImageTag { get; set; }
    public string? SeriesThumbImageTag { get; set; }
    public string? SeriesPrimaryImageTag { get; set; }
    public ImageBlurHashes? ImageBlurHashes { get; set; }
    public double? PrimaryImageAspectRatio { get; set; }
    public bool? IsFolder { get; set; }
    public List<ChapterInfo>? Chapters { get; set; }
    public Dictionary<string, Dictionary<string, TrickplayInfoDto>>? Trickplay { get; set; }
}

public sealed class BaseItemDtoQueryResult
{
    public List<BaseItemDto>? Items { get; set; }
    public int? TotalRecordCount { get; set; }
}

public sealed class QueryFilters
{
    public List<NameGuidPair>? Genres { get; set; }
}

public sealed class QueryFiltersLegacy
{
    public List<int>? Years { get; set; }
}

public sealed class PlaybackInfoResponse
{
    public List<MediaSourceInfo>? MediaSources { get; set; }
    public string? PlaySessionId { get; set; }
    public string? ErrorCode { get; set; }
}

public sealed class MediaSegmentDto
{
    public string? Type { get; set; }
    public long? StartTicks { get; set; }
    public long? EndTicks { get; set; }
}

public sealed class MediaSegmentDtoQueryResult
{
    public List<MediaSegmentDto>? Items { get; set; }
}

/// <summary>Rapport de lecture (début, progression, fin) envoyé au serveur.</summary>
public sealed class PlaybackReportDto
{
    public string ItemId { get; set; } = "";
    public string? MediaSourceId { get; set; }
    public string? PlaySessionId { get; set; }
    public long PositionTicks { get; set; }
    public bool? IsPaused { get; set; }
    public bool? IsMuted { get; set; }
    public bool? CanSeek { get; set; }
    public string? PlayMethod { get; set; }
    public int? AudioStreamIndex { get; set; }
    public int? SubtitleStreamIndex { get; set; }
    public bool? Failed { get; set; }
}

public sealed class AuthenticateUserByName
{
    public string Username { get; set; } = "";
    public string Pw { get; set; } = "";
}

public sealed class QuickConnectDto
{
    public string Secret { get; set; } = "";
}

/// <summary>Découverte UDP : réponse d'un serveur du réseau local.</summary>
public sealed class DiscoveryResponse
{
    public string? Id { get; set; }
    public string? Address { get; set; }
    public string? Name { get; set; }
}

[JsonSourceGenerationOptions(
    PropertyNameCaseInsensitive = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.Unspecified,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    NumberHandling = JsonNumberHandling.AllowReadingFromString)]
[JsonSerializable(typeof(PublicSystemInfo))]
[JsonSerializable(typeof(List<UserDto>))]
[JsonSerializable(typeof(UserDto))]
[JsonSerializable(typeof(AuthenticationResult))]
[JsonSerializable(typeof(QuickConnectResult))]
[JsonSerializable(typeof(BaseItemDto))]
[JsonSerializable(typeof(List<BaseItemDto>))]
[JsonSerializable(typeof(BaseItemDtoQueryResult))]
[JsonSerializable(typeof(UserItemDataDto))]
[JsonSerializable(typeof(QueryFilters))]
[JsonSerializable(typeof(QueryFiltersLegacy))]
[JsonSerializable(typeof(PlaybackInfoResponse))]
[JsonSerializable(typeof(MediaSegmentDtoQueryResult))]
[JsonSerializable(typeof(PlaybackReportDto))]
[JsonSerializable(typeof(AuthenticateUserByName))]
[JsonSerializable(typeof(QuickConnectDto))]
[JsonSerializable(typeof(DiscoveryResponse))]
[JsonSerializable(typeof(JsonObject))]
[JsonSerializable(typeof(JsonElement))]
public sealed partial class JellyfinJson : JsonSerializerContext;
