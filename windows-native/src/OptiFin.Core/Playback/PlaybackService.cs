using System.Text.Json.Nodes;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;

namespace OptiFin.Core.Playback;

/// <summary>
/// Préparation des lectures (PlaybackInfo), compléments (chapitres, segments, épisode suivant)
/// et rapports de progression au serveur.
///
/// Sur Windows, libmpv lit pratiquement tout tel quel (HEVC, AV1, Dolby Vision, DTS, TrueHD,
/// ASS, PGS…) avec le décodage matériel de la carte graphique : la lecture directe est la règle.
/// Le serveur ne transcode que si le débit dépasse la limite réglée, ou en repli si la lecture
/// directe échoue.
/// </summary>
public sealed class PlaybackService(JellyfinClient api, string userId)
{
    public const long DefaultMaxBitrate = 200_000_000;

    public async Task<PlaybackPlan> PrepareAsync(string itemId, TimeSpan start, int? audioIndex = null, int? subtitleIndex = null,
        bool forceTranscode = false, long maxBitrate = DefaultMaxBitrate, string? mediaSourceId = null, CancellationToken ct = default)
    {
        var body = new JsonObject
        {
            ["UserId"] = userId,
            ["MaxStreamingBitrate"] = maxBitrate,
            ["StartTimeTicks"] = start.Ticks,
            ["DeviceProfile"] = MpvDeviceProfile(maxBitrate),
            ["EnableDirectPlay"] = !forceTranscode,
            ["EnableDirectStream"] = !forceTranscode,
            ["EnableTranscoding"] = true,
            ["AllowVideoStreamCopy"] = true,
            ["AllowAudioStreamCopy"] = true,
            ["AutoOpenLiveStream"] = true,
        };
        if (audioIndex is { } a) body["AudioStreamIndex"] = a;
        // -1 explicite : sans cela, le serveur pourrait incruster un sous-titre par défaut.
        body["SubtitleStreamIndex"] = subtitleIndex ?? -1;
        if (mediaSourceId != null) body["MediaSourceId"] = mediaSourceId;
        var response = await api.PostAsync($"Items/{itemId}/PlaybackInfo", JellyfinClient.Json(body),
            JellyfinJson.Default.PlaybackInfoResponse, ct: ct);
        return PlanFromResponse(response, itemId, api.BaseUrl, start, audioIndex, subtitleIndex);
    }

    /// <summary>Réponse PlaybackInfo → plan de lecture (pur, testé).</summary>
    public static PlaybackPlan PlanFromResponse(PlaybackInfoResponse response, string itemId, Uri baseUrl, TimeSpan start,
        int? requestedAudio = null, int? requestedSubtitle = null)
    {
        if (!string.IsNullOrEmpty(response.ErrorCode) && response.ErrorCode != "Unknown")
            throw new ApiException(ApiErrorKind.PlaybackDenied, response.ErrorCode);
        var source = response.MediaSources?.FirstOrDefault() ?? throw new ApiException(ApiErrorKind.PlaybackDenied, "NoCompatibleStream");

        PlayMethod method;
        Uri url;
        if (source.SupportsDirectPlay == true)
        {
            method = PlayMethod.DirectPlay;
            url = Urls.Resolve(baseUrl, $"Videos/{itemId}/stream",
            [
                new("static", "true"), new("mediaSourceId", source.Id ?? itemId), new("playSessionId", response.PlaySessionId),
                new("tag", source.ETag),
            ]);
        }
        else if (source.TranscodingUrl is { } transcoding)
        {
            method = source.SupportsDirectStream == true ? PlayMethod.DirectStream : PlayMethod.Transcode;
            url = Urls.Resolve(baseUrl, WithoutApiKey(transcoding));
        }
        else
        {
            throw new ApiException(ApiErrorKind.PlaybackDenied, "NoCompatibleStream");
        }

        var streams = (source.MediaStreams ?? []).OrderBy(s => s.Index ?? 0).ToList();
        var audio = streams.Where(s => s.Type == "Audio" && s.Index != null).Select(s => Track(s, TrackType.Audio)).ToList();
        var subtitles = streams.Where(s => s.Type == "Subtitle" && s.Index != null).Select(s => Track(s, TrackType.Subtitle)).ToList();
        var video = streams.FirstOrDefault(s => s.Type == "Video");
        var defaultSub = requestedSubtitle ?? source.DefaultSubtitleStreamIndex;
        return new PlaybackPlan
        {
            ItemId = itemId,
            MediaSourceId = source.Id ?? itemId,
            PlaySessionId = response.PlaySessionId,
            Method = method,
            StreamUrl = url,
            AudioTracks = audio,
            SubtitleTracks = subtitles,
            AudioIndex = requestedAudio ?? source.DefaultAudioStreamIndex ?? audio.FirstOrDefault()?.Index,
            SubtitleIndex = defaultSub is null or < 0 || subtitles.All(t => t.Index != defaultSub) ? null : defaultSub,
            Container = source.Container,
            Bitrate = source.Bitrate,
            VideoCodec = video?.Codec,
            VideoRangeType = video?.VideoRangeType,
            Start = start,
            Runtime = source.RunTimeTicks is { } t ? TimeSpan.FromTicks(t) : null,
        };
    }

    /// <summary>
    /// L'URL de transcodage du serveur contient la clé d'API : retirée, l'authentification part
    /// dans l'en-tête (jamais de jeton dans une URL ni dans les journaux).
    /// </summary>
    public static string WithoutApiKey(string url)
    {
        var q = url.IndexOf('?');
        if (q < 0) return url;
        var kept = url[(q + 1)..].Split('&')
            .Where(p => !p.StartsWith("api_key=", StringComparison.OrdinalIgnoreCase) &&
                        !p.StartsWith("ApiKey=", StringComparison.OrdinalIgnoreCase));
        var query = string.Join('&', kept);
        return query.Length == 0 ? url[..q] : $"{url[..q]}?{query}";
    }

    private static MediaTrack Track(MediaStream s, TrackType type)
    {
        var language = s.Language;
        var codec = s.Codec?.ToLowerInvariant();
        var fallbackParts = new List<string>();
        if (!string.IsNullOrEmpty(language)) fallbackParts.Add(language.ToUpperInvariant());
        if (codec != null) fallbackParts.Add(codec.ToUpperInvariant());
        if (type == TrackType.Audio && s.Channels != null) fallbackParts.Add($"{s.Channels} can.");
        var fallback = string.Join(" · ", fallbackParts);
        return new MediaTrack(
            s.Index!.Value, type,
            !string.IsNullOrEmpty(s.DisplayTitle) ? s.DisplayTitle! : fallback.Length == 0 ? $"Piste {s.Index}" : fallback,
            language, codec, s.IsDefault ?? false, s.IsForced ?? false, s.IsExternal ?? false, s.IsTextSubtitleStream ?? true,
            s.DeliveryUrl, s.Channels);
    }

    /// <summary>
    /// Profil libmpv : lecture directe de pratiquement tout. Le transcodage (débit trop élevé, repli)
    /// se fait en HLS HEVC/H.264 ; sous-titres image incrustés par le serveur dans ce cas.
    /// </summary>
    public static JsonObject MpvDeviceProfile(long maxBitrate)
    {
        string[] text = ["srt", "subrip", "ass", "ssa", "vtt", "webvtt", "ttml", "sub", "smi"];
        string[] bitmap = ["pgs", "pgssub", "dvdsub", "dvbsub", "vobsub", "xsub"];
        var subtitles = new JsonArray();
        foreach (var f in text.Concat(bitmap)) subtitles.Add((JsonNode)new JsonObject { ["Format"] = f, ["Method"] = "Embed" });
        foreach (var f in text) subtitles.Add((JsonNode)new JsonObject { ["Format"] = f, ["Method"] = "External" });
        foreach (var f in bitmap) subtitles.Add((JsonNode)new JsonObject { ["Format"] = f, ["Method"] = "Encode" });
        return new JsonObject
        {
            ["Name"] = "OptiFin (Windows, mpv)",
            ["MaxStreamingBitrate"] = maxBitrate,
            ["MaxStaticBitrate"] = 400_000_000,
            ["MusicStreamingTranscodingBitrate"] = 320_000,
            ["DirectPlayProfiles"] = new JsonArray(
                new JsonObject
                {
                    ["Type"] = "Video",
                    ["Container"] = "mkv,mp4,m4v,mov,webm,avi,ts,m2ts,mts,mpegts,wmv,asf,flv,3gp,ogv,ogm,vob,mpg,mpeg",
                },
                new JsonObject { ["Type"] = "Audio", ["Container"] = "mp3,aac,m4a,m4b,flac,alac,wav,ogg,oga,opus,wma,ape,wv,mka,webma" }),
            ["TranscodingProfiles"] = new JsonArray(
                new JsonObject
                {
                    ["Type"] = "Video", ["Container"] = "ts", ["Protocol"] = "hls", ["Context"] = "Streaming",
                    ["VideoCodec"] = "hevc,h264", ["AudioCodec"] = "aac,ac3,eac3,mp3,opus", ["MaxAudioChannels"] = "8",
                    ["MinSegments"] = 1, ["BreakOnNonKeyFrames"] = true,
                },
                new JsonObject
                {
                    ["Type"] = "Audio", ["Container"] = "mp3", ["Protocol"] = "http", ["Context"] = "Streaming", ["AudioCodec"] = "mp3",
                }),
            ["ContainerProfiles"] = new JsonArray(),
            ["CodecProfiles"] = new JsonArray(),
            ["SubtitleProfiles"] = subtitles,
        };
    }

    // ------------------------------------------------------------ Compléments

    /// <summary>Sous-titres proposés par les fournisseurs du serveur (langue ISO 639-2, ex. « fre »).</summary>
    public async Task<IReadOnlyList<RemoteSubtitle>> SearchSubtitlesAsync(string itemId, string language, CancellationToken ct = default)
    {
        var list = await api.GetAsync($"Items/{itemId}/RemoteSearch/Subtitles/{language}", JellyfinJson.Default.JsonElement, ct: ct);
        return RemoteSubtitle.FromJson(list);
    }

    /// <summary>Télécharge un sous-titre sur le serveur (il rejoint ensuite les pistes de l'élément).</summary>
    public Task DownloadSubtitleAsync(string itemId, string subtitleId, CancellationToken ct = default) =>
        api.PostAsync($"Items/{itemId}/RemoteSearch/Subtitles/{Uri.EscapeDataString(subtitleId)}", ct: ct);

    public async Task<PlaybackExtras> ExtrasAsync(MediaItem item, MediaRepository media, CancellationToken ct = default)
    {
        async Task<T?> Safe<T>(string what, Func<Task<T?>> call) where T : class
        {
            try
            {
                return await call();
            }
            catch (Exception e) when (e is not OperationCanceledException)
            {
                AppLog.Warn("extras", $"{what} indisponible : {e.Message}");
                return null;
            }
        }

        var chapters = Safe<BaseItemDtoQueryResult>("chapitres", async () => await api.GetAsync($"Users/{userId}/Items", JellyfinJson.Default.BaseItemDtoQueryResult,
            [new("Ids", item.Id), new("Fields", "Chapters"), new("EnableImages", "false"), new("EnableTotalRecordCount", "false")], ct));
        var segments = Safe<MediaSegmentDtoQueryResult>("segments", async () => await api.GetAsync($"MediaSegments/{item.Id}", JellyfinJson.Default.MediaSegmentDtoQueryResult, ct: ct));
        var next = item.Kind == MediaKind.Episode
            ? Safe<MediaItem>("épisode suivant", () => media.NextEpisodeAsync(item, ct))
            : Task.FromResult<MediaItem?>(null);
        await Task.WhenAll(chapters, segments, next);
        return new PlaybackExtras(
            ChaptersFrom(chapters.Result?.Items?.FirstOrDefault()),
            SegmentsFrom(segments.Result?.Items ?? []),
            next.Result);
    }

    public static IReadOnlyList<Chapter> ChaptersFrom(BaseItemDto? dto) =>
        [.. (dto?.Chapters ?? []).Select((c, i) => new Chapter(i, TimeSpan.FromTicks(c.StartPositionTicks ?? 0),
            string.IsNullOrWhiteSpace(c.Name) ? $"Chapitre {i + 1}" : c.Name.Trim(), c.ImageTag)).OrderBy(c => c.Start)];

    public static IReadOnlyList<MediaSegment> SegmentsFrom(IEnumerable<MediaSegmentDto> dtos)
    {
        var result = new List<MediaSegment>();
        foreach (var d in dtos)
        {
            SegmentType? type = d.Type switch
            {
                "Intro" => SegmentType.Intro,
                "Recap" => SegmentType.Recap,
                "Preview" => SegmentType.Preview,
                "Commercial" => SegmentType.Commercial,
                "Outro" => SegmentType.Outro,
                _ => null,
            };
            if (type is null || d.StartTicks is not { } s || d.EndTicks is not { } e || e <= s) continue;
            result.Add(new MediaSegment(type.Value, TimeSpan.FromTicks(s), TimeSpan.FromTicks(e)));
        }
        return [.. result.OrderBy(s => s.Start)];
    }

    // ------------------------------------------------------------ Rapports au serveur

    private PlaybackReportDto Report(PlaybackPlan plan, TimeSpan position, bool paused) => new()
    {
        ItemId = plan.ItemId,
        MediaSourceId = plan.MediaSourceId,
        PlaySessionId = plan.PlaySessionId,
        PositionTicks = position.Ticks,
        IsPaused = paused,
        IsMuted = false,
        CanSeek = true,
        PlayMethod = plan.Method.ApiName(),
        AudioStreamIndex = plan.AudioIndex,
        SubtitleStreamIndex = plan.SubtitleIndex ?? -1,
    };

    public Task ReportStartAsync(PlaybackPlan plan, TimeSpan position) =>
        SafeReport("début", () => api.PostAsync("Sessions/Playing",
            JellyfinClient.Json(Report(plan, position, false), JellyfinJson.Default.PlaybackReportDto)));

    public Task ReportProgressAsync(PlaybackPlan plan, TimeSpan position, bool paused) =>
        SafeReport("progression", () => api.PostAsync("Sessions/Playing/Progress",
            JellyfinClient.Json(Report(plan, position, paused), JellyfinJson.Default.PlaybackReportDto)));

    public Task ReportStoppedAsync(PlaybackPlan plan, TimeSpan position, bool failed = false)
    {
        var report = new PlaybackReportDto
        {
            ItemId = plan.ItemId,
            MediaSourceId = plan.MediaSourceId,
            PlaySessionId = plan.PlaySessionId,
            PositionTicks = position.Ticks,
            Failed = failed,
        };
        return SafeReport("fin", () => api.PostAsync("Sessions/Playing/Stopped",
            JellyfinClient.Json(report, JellyfinJson.Default.PlaybackReportDto)));
    }

    /// <summary>Rapports au mieux : une coupure réseau ne doit jamais interrompre la lecture.</summary>
    private static async Task SafeReport(string what, Func<Task> call)
    {
        try
        {
            await call();
        }
        catch (Exception e)
        {
            AppLog.Warn("report", $"Rapport « {what} » non envoyé : {e.Message}");
        }
    }
}
