using System.Text.RegularExpressions;
using OptiFin.Core.Api;

namespace OptiFin.Core.Media;

/// <summary>
/// <see cref="BaseItemDto"/> → <see cref="MediaItem"/>. Tolérant aux champs absents : le serveur
/// ne renvoie que les <c>Fields</c> demandés.
/// </summary>
public static partial class MediaMapper
{
    public static MediaItem FromDto(BaseItemDto dto)
    {
        var blur = dto.ImageBlurHashes;
        static string? BlurOf(Dictionary<string, string>? map, string? tag) =>
            tag != null && map != null && map.TryGetValue(tag, out var h) ? h : null;

        ImageRef? Own(ImageKind kind, string key, Dictionary<string, string>? blurs) =>
            dto.ImageTags != null && dto.ImageTags.TryGetValue(key, out var tag)
                ? new ImageRef(dto.Id, kind, tag, BlurOf(blurs, tag))
                : null;

        var backdrops = (dto.BackdropImageTags ?? []).Select((tag, i) =>
            new ImageRef(dto.Id, ImageKind.Backdrop, tag, BlurOf(blur?.Backdrop, tag), i)).ToList();

        var parentBackdropTag = dto.ParentBackdropImageTags?.FirstOrDefault();
        var parentBackdrop = dto.ParentBackdropItemId != null && parentBackdropTag != null
            ? new ImageRef(dto.ParentBackdropItemId, ImageKind.Backdrop, parentBackdropTag, BlurOf(blur?.Backdrop, parentBackdropTag))
            : null;

        var logo = Own(ImageKind.Logo, "Logo", blur?.Logo) ??
                   (dto.ParentLogoItemId != null && dto.ParentLogoImageTag != null
                       ? new ImageRef(dto.ParentLogoItemId, ImageKind.Logo, dto.ParentLogoImageTag, BlurOf(blur?.Logo, dto.ParentLogoImageTag))
                       : null);

        var parentThumb = dto.ParentThumbItemId != null && dto.ParentThumbImageTag != null
            ? new ImageRef(dto.ParentThumbItemId, ImageKind.Thumb, dto.ParentThumbImageTag, BlurOf(blur?.Thumb, dto.ParentThumbImageTag))
            : dto.SeriesId != null && dto.SeriesThumbImageTag != null
                ? new ImageRef(dto.SeriesId, ImageKind.Thumb, dto.SeriesThumbImageTag)
                : null;

        var seriesPrimary = dto.SeriesId != null && dto.SeriesPrimaryImageTag != null
            ? new ImageRef(dto.SeriesId, ImageKind.Primary, dto.SeriesPrimaryImageTag, BlurOf(blur?.Primary, dto.SeriesPrimaryImageTag))
            : null;

        var ud = dto.UserData;
        return new MediaItem
        {
            Id = dto.Id,
            Name = dto.Name ?? "",
            Kind = KindOf(dto.Type),
            OriginalTitle = dto.OriginalTitle,
            Overview = Clean(dto.Overview),
            Tagline = dto.Taglines?.FirstOrDefault(),
            Year = dto.ProductionYear,
            PremiereDate = dto.PremiereDate,
            EndDate = dto.EndDate,
            Status = dto.Status,
            RunTimeTicks = dto.RunTimeTicks ?? dto.CumulativeRunTimeTicks,
            CommunityRating = dto.CommunityRating,
            CriticRating = dto.CriticRating,
            OfficialRating = dto.OfficialRating,
            Genres = [.. (dto.GenreItems ?? []).Where(g => g.Id != null && g.Name != null).Select(g => new NamedRef(g.Id!, g.Name!))],
            Studios = [.. (dto.Studios ?? []).Where(g => g.Id != null && g.Name != null).Select(g => new NamedRef(g.Id!, g.Name!))],
            People = [.. (dto.People ?? []).Select(p => new PersonCredit(p.Id, p.Name ?? "",
                string.IsNullOrEmpty(p.Role) ? null : p.Role, PersonKindOf(p.Type),
                p.PrimaryImageTag == null ? null : new ImageRef(p.Id, ImageKind.Primary, p.PrimaryImageTag)))],
            Trailers = [.. (dto.RemoteTrailers ?? [])
                .Where(t => Uri.TryCreate(t.Url, UriKind.Absolute, out _))
                .Select(t => new Trailer(new Uri(t.Url!), t.Name))],
            LocalTrailerCount = dto.LocalTrailerCount ?? 0,
            User = new UserState(ud?.Played ?? false, ud?.IsFavorite ?? false, ud?.PlaybackPositionTicks ?? 0,
                ud?.PlayedPercentage, ud?.UnplayedItemCount),
            SeriesId = dto.SeriesId,
            SeriesName = dto.SeriesName,
            SeasonId = dto.SeasonId,
            SeasonName = dto.SeasonName,
            IndexNumber = dto.IndexNumber,
            ParentIndexNumber = dto.ParentIndexNumber,
            ChildCount = dto.ChildCount ?? dto.RecursiveItemCount,
            LibraryType = LibraryTypeOf(dto.CollectionType),
            Streams = Streams(dto),
            Primary = Own(ImageKind.Primary, "Primary", blur?.Primary),
            Backdrops = backdrops,
            Logo = logo,
            Thumb = Own(ImageKind.Thumb, "Thumb", blur?.Thumb),
            ParentBackdrop = parentBackdrop,
            ParentThumb = parentThumb,
            SeriesPrimary = seriesPrimary,
            PrimaryAspectRatio = dto.PrimaryImageAspectRatio,
            IsFolder = dto.IsFolder ?? false,
        };
    }

    public static MediaKind KindOf(string? type) => type switch
    {
        "Movie" => MediaKind.Movie,
        "Series" => MediaKind.Series,
        "Season" => MediaKind.Season,
        "Episode" => MediaKind.Episode,
        "BoxSet" => MediaKind.BoxSet,
        "Folder" or "AggregateFolder" => MediaKind.Folder,
        "CollectionFolder" or "UserView" => MediaKind.CollectionFolder,
        "Person" => MediaKind.Person,
        "MusicAlbum" => MediaKind.MusicAlbum,
        "MusicArtist" => MediaKind.MusicArtist,
        "Audio" or "AudioBook" => MediaKind.Audio,
        "Playlist" => MediaKind.Playlist,
        "Video" => MediaKind.Video,
        "MusicVideo" => MediaKind.MusicVideo,
        "Photo" => MediaKind.Photo,
        "PhotoAlbum" => MediaKind.PhotoAlbum,
        "Trailer" => MediaKind.Trailer,
        "TvChannel" or "LiveTvChannel" => MediaKind.TvChannel,
        _ => MediaKind.Other,
    };

    public static LibraryType? LibraryTypeOf(string? type) => type?.ToLowerInvariant() switch
    {
        null => null,
        "movies" => LibraryType.Movies,
        "tvshows" => LibraryType.TvShows,
        "music" => LibraryType.Music,
        "musicvideos" => LibraryType.MusicVideos,
        "homevideos" => LibraryType.HomeVideos,
        "boxsets" => LibraryType.BoxSets,
        "books" => LibraryType.Books,
        "photos" => LibraryType.Photos,
        "livetv" => LibraryType.LiveTv,
        "playlists" => LibraryType.Playlists,
        "folders" => LibraryType.Folders,
        _ => LibraryType.Unknown,
    };

    private static PersonKind PersonKindOf(string? t) => t switch
    {
        "Actor" => PersonKind.Actor,
        "GuestStar" => PersonKind.GuestStar,
        "Director" => PersonKind.Director,
        "Writer" => PersonKind.Writer,
        "Producer" => PersonKind.Producer,
        "Composer" => PersonKind.Composer,
        _ => PersonKind.Other,
    };

    public static VideoRange VideoRangeOf(string? t) => t switch
    {
        "DOVI" or "DOVIWithHDR10" or "DOVIWithHLG" or "DOVIWithSDR" or "DOVIWithEL" or "DOVIWithHDR10Plus" or "DOVIWithELHDR10Plus"
            => VideoRange.DolbyVision,
        "HDR10Plus" => VideoRange.Hdr10Plus,
        "HDR10" => VideoRange.Hdr10,
        "HLG" => VideoRange.Hlg,
        _ => VideoRange.Sdr,
    };

    /// <summary>Flux de la première source (ou de l'élément si MediaSources n'est pas demandé).</summary>
    private static IReadOnlyList<StreamSummary> Streams(BaseItemDto dto)
    {
        var streams = dto.MediaSources?.FirstOrDefault()?.MediaStreams ?? dto.MediaStreams ?? [];
        var result = new List<StreamSummary>();
        foreach (var s in streams)
        {
            var codec = (s.Codec ?? "").ToLowerInvariant();
            if (s.Type == "Video")
            {
                result.Add(new StreamSummary(true, codec, s.Width, s.Height, VideoRangeOf(s.VideoRangeType), s.BitDepth));
            }
            else if (s.Type == "Audio")
            {
                var spatial = s.AudioSpatialFormat switch
                {
                    "DolbyAtmos" => SpatialAudio.Atmos,
                    "DTSX" => SpatialAudio.DtsX,
                    _ => SpatialAudio.None,
                };
                result.Add(new StreamSummary(false, codec, Profile: s.Profile, Channels: s.Channels, Spatial: spatial,
                    Language: s.Language, Title: s.DisplayTitle));
            }
        }
        return result;
    }

    [GeneratedRegex(@"<br\s*/?>", RegexOptions.IgnoreCase)]
    private static partial Regex BreakPattern();

    [GeneratedRegex("<[^>]+>")]
    private static partial Regex TagPattern();

    /// <summary>Retire les balises HTML parfois présentes dans les synopsis.</summary>
    public static string? Clean(string? text)
    {
        if (text is null) return null;
        var cleaned = TagPattern().Replace(BreakPattern().Replace(text, "\n"), "")
            .Replace("&amp;", "&").Replace("&quot;", "\"").Replace("&#39;", "'").Trim();
        return cleaned.Length == 0 ? null : cleaned;
    }
}
