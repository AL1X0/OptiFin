using System.Net;
using System.Text;
using OptiFin.Core.Api;
using OptiFin.Core.Auth;
using OptiFin.Core.Localization;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using OptiFin.Core.Playback;
using OptiFin.Core.Settings;

namespace OptiFin.Core.Tests;

public class ServerAddressTests
{
    [Fact]
    public void SansSchema_httpsPuisHttpPuisPortParDefaut()
    {
        var c = ServerAddress.Candidates("  jellyfin.maison/ ");
        Assert.Equal(["https://jellyfin.maison/", "http://jellyfin.maison/", "http://jellyfin.maison:8096/"],
            c.Select(u => u.ToString()));
    }

    [Fact]
    public void PortExplicite_pasDe8096()
    {
        var c = ServerAddress.Candidates("192.168.1.20:8920");
        Assert.Equal(2, c.Count);
        Assert.All(c, u => Assert.Equal(8920, u.Port));
    }

    [Fact]
    public void SchemaExplicite_gardeLeSousChemin()
    {
        var c = ServerAddress.Candidates("HTTPS://Exemple.FR/jellyfin/?x=1#y");
        Assert.Equal("https://exemple.fr/jellyfin", Assert.Single(c).ToString());
    }

    [Theory]
    [InlineData("")]
    [InlineData("ftp://serveur")]
    [InlineData("https://")]
    public void SaisieInexploitable_rien(string input) => Assert.Empty(ServerAddress.Candidates(input));

    [Theory]
    [InlineData("10.9.0", true)]
    [InlineData("10.10.7", true)]
    [InlineData("10.11.0-rc1", true)]
    [InlineData("10.8.13", false)]
    [InlineData("n/a", false)]
    public void Versions(string version, bool supported) => Assert.Equal(supported, ServerAddress.IsSupportedVersion(version));

    [Fact]
    public void Decouverte_reponseValide()
    {
        var s = ServerDiscovery.Parse(Encoding.UTF8.GetBytes("{\"Address\":\"http://192.168.1.20:8096\",\"Id\":\"abc\",\"Name\":\"Maison\"}"));
        Assert.NotNull(s);
        Assert.Equal("Maison", s.Name);
        Assert.Equal(8096, s.Address.Port);
        Assert.Null(ServerDiscovery.Parse(Encoding.UTF8.GetBytes("pas du json")));
        Assert.Null(ServerDiscovery.Parse(Encoding.UTF8.GetBytes("{\"Id\":\"\"}")));
    }
}

public class ClientTests
{
    [Fact]
    public void EnTeteAuthorization_encodeEtJeton()
    {
        var id = new ClientIdentity("OptiFin", "PC de Léa, \"salon\"", "dev-1", "1.0.0");
        var h = id.AuthorizationHeader("secret");
        Assert.StartsWith("MediaBrowser Client=\"OptiFin\"", h);
        Assert.Contains("Device=\"PC%20de%20L%C3%A9a%2C%20%22salon%22\"", h);
        Assert.EndsWith("Token=\"secret\"", h);
        Assert.DoesNotContain("Token", id.AuthorizationHeader(null));
    }

    [Fact]
    public void Urls_gardeLeSousCheminEtFusionneLaRequete()
    {
        var u = Urls.Resolve(new Uri("https://h.fr/jellyfin"), "/Videos/1/master.m3u8?a=1", [new("b", "2"), new("c", null)]);
        Assert.Equal("https://h.fr/jellyfin/Videos/1/master.m3u8?a=1&b=2", u.ToString());
    }

    [Fact]
    public void Journal_masqueLesSecrets()
    {
        var s = AppLog.Redact("Token=\"abc\" api_key=123&x=1 \"AccessToken\":\"zz\" X-Emby-Token: tok");
        Assert.DoesNotContain("abc", s);
        Assert.DoesNotContain("123", s);
        Assert.DoesNotContain("zz", s);
        Assert.DoesNotContain("tok", s);
    }
}

public class AccountStoreTests
{
    [Fact]
    public void JetonChiffre_etRestaure()
    {
        var dir = Path.Combine(Path.GetTempPath(), "optifin-tests-" + Guid.NewGuid());
        try
        {
            var store = new AccountStore(dir);
            var server = new JellyfinServer("srv", "Maison", new Uri("https://h.fr"), "10.10.7");
            store.Remember(new ActiveSession(server, new Account("srv", "u1", "Léa"), "jeton-secret"));
            Assert.DoesNotContain("jeton-secret", File.ReadAllText(Path.Combine(dir, "accounts.json")));
            var restored = new AccountStore(dir).Restore();
            Assert.Equal("jeton-secret", restored?.Token);
            Assert.Equal("Léa", restored?.Account.UserName);
            store.SignOut("srv:u1", forget: false);
            Assert.Null(store.Restore("srv:u1"));
            Assert.Single(store.Accounts());
            Assert.Equal(store.DeviceId(), new AccountStore(dir).DeviceId());
        }
        finally
        {
            Directory.Delete(dir, recursive: true);
        }
    }
}

public class MediaTests
{
    private static BaseItemDto Episode() => new()
    {
        Id = "e1",
        Name = "La suite",
        Type = "Episode",
        SeriesId = "s1",
        SeriesName = "Les Veilleurs",
        IndexNumber = 3,
        ParentIndexNumber = 2,
        RunTimeTicks = TimeSpan.FromMinutes(52).Ticks,
        ImageTags = new() { ["Primary"] = "p" },
        SeriesPrimaryImageTag = "sp",
        ParentBackdropItemId = "s1",
        ParentBackdropImageTags = ["pb"],
        Overview = "Il <b>revient</b>.<br/>Enfin &amp; vite.",
        UserData = new UserItemDataDto { PlayedPercentage = 40, PlaybackPositionTicks = TimeSpan.FromMinutes(20).Ticks },
        MediaStreams =
        [
            new MediaStream { Type = "Video", Codec = "HEVC", Width = 3840, Height = 1600, VideoRangeType = "DOVIWithHDR10" },
            new MediaStream { Type = "Audio", Codec = "truehd", Channels = 8, AudioSpatialFormat = "DolbyAtmos" },
        ],
    };

    [Fact]
    public void Episode_imagesEtLibelle()
    {
        var item = MediaMapper.FromDto(Episode());
        Assert.Equal(MediaKind.Episode, item.Kind);
        Assert.Equal("S2 · É3", item.EpisodeLabel);
        Assert.Equal("sp", item.Poster?.Tag);
        Assert.Equal("p", item.Landscape?.Tag);
        Assert.Equal("pb", item.Backdrop?.Tag);
        Assert.Equal("Il revient.\nEnfin & vite.", item.Overview);
        Assert.Equal(0.4, item.User.Progress);
        Assert.Equal("32 min restantes", MediaFormat.Remaining(item));
    }

    [Fact]
    public void Badges_unParCategorie_lePlusPremium()
    {
        var badges = QualityBadges.For(MediaMapper.FromDto(Episode()).Streams);
        Assert.Equal(["4K", "Dolby Vision", "Atmos", "7.1"], badges);
    }

    [Fact]
    public void LigneDeMetadonnees()
    {
        var movie = new MediaItem
        {
            Id = "m", Name = "Brume", Kind = MediaKind.Movie, Year = 2024, RunTimeTicks = TimeSpan.FromMinutes(101).Ticks,
            OfficialRating = "12", CommunityRating = 6.9,
        };
        Assert.Equal(["2024", "1 h 41 min", "12", "★ 6,9"], MediaFormat.MetadataLine(movie));
        var series = movie with { Kind = MediaKind.Series, ChildCount = 3, Status = "Continuing" };
        Assert.Equal(["2024 –", "3 saisons", "12", "★ 6,9"], MediaFormat.MetadataLine(series));
        Assert.Equal("1:02:03", MediaFormat.Clock(new TimeSpan(1, 2, 3)));
        Assert.Equal("4:05", MediaFormat.Clock(new TimeSpan(0, 4, 5)));
    }

    [Fact]
    public void ImagesRedimensionnees_parPalier()
    {
        var urls = new ImageUrls(new Uri("https://h.fr/jf"));
        var u = urls.Image(new ImageRef("i1", ImageKind.Backdrop, "t", Index: 2), 700, 1.5);
        Assert.Equal("https://h.fr/jf/Items/i1/Images/Backdrop/2?maxWidth=1080&quality=90&format=Webp&tag=t", u.ToString());
    }

    [Fact]
    public void Logos_gardent_leur_transparence_sans_decodeur_WebP()
    {
        var urls = new ImageUrls(new Uri("https://h.fr"));
        ImageUrls.Format = "Jpg";
        try
        {
            Assert.Contains("format=Png", urls.Image(new ImageRef("i", ImageKind.Logo, "t"), 400).ToString());
            Assert.Contains("format=Png", urls.Image(new ImageRef("i", ImageKind.Art, "t"), 400).ToString());
            Assert.Contains("format=Jpg", urls.Image(new ImageRef("i", ImageKind.Primary, "t"), 400).ToString());
            Assert.Contains("format=Jpg", urls.Image(new ImageRef("i", ImageKind.Backdrop, "t"), 400).ToString());
        }
        finally
        {
            ImageUrls.Format = "Webp";
        }
        Assert.Contains("format=Webp", urls.Image(new ImageRef("i", ImageKind.Logo, "t"), 400).ToString());
    }

    [Fact]
    public void Accueil_aSuivreSansDoublonsEtVitrineAvecFond()
    {
        var snapshot = new HomeSnapshot
        {
            Views = [new BaseItemDto { Id = "lib", Name = "Films", CollectionType = "movies" }],
            Resume = [new BaseItemDto { Id = "e1", Type = "Episode" }],
            NextUp = [new BaseItemDto { Id = "e1", Type = "Episode" }, new BaseItemDto { Id = "e2", Type = "Episode" }],
            Latest = new() { ["lib"] = [new BaseItemDto { Id = "m1", Type = "Movie" }] },
            Featured = [new BaseItemDto { Id = "f1", Type = "Movie", BackdropImageTags = ["b"] }, new BaseItemDto { Id = "f2", Type = "Movie" }],
        };
        var home = HomeRepository.Build(snapshot, fromCache: false);
        Assert.Equal(["Reprendre", "À suivre", "Ajouts récents · Films"], home.Sections.Select(s => s.Title));
        Assert.Equal("e2", Assert.Single(home.Sections[1].Items).Id);
        Assert.Equal("f1", Assert.Single(home.Featured).Id);
    }

    [Fact]
    public void BandesAnnonces_httpEtHttpsSeulement()
    {
        var item = MediaMapper.FromDto(new BaseItemDto
        {
            Id = "m1",
            Name = "Film",
            Type = "Movie",
            RemoteTrailers =
            [
                new MediaUrl { Url = "https://youtu.be/x", Name = "Bande-annonce" },
                new MediaUrl { Url = "http://exemple.fr/ba.mp4" },
                new MediaUrl { Url = "ms-settings:privacy" },
                new MediaUrl { Url = "file:///C:/x.exe" },
                new MediaUrl { Url = "javascript:alert(1)" },
                new MediaUrl { Url = "pas une url" },
            ],
        });
        Assert.Equal(["https://youtu.be/x", "http://exemple.fr/ba.mp4"],
            item.Trailers.Select(t => t.Url.ToString()));
    }

    [Fact]
    public void Versions_mapperEtLabels()
    {
        var dto = new BaseItemDto
        {
            Id = "m1",
            Name = "Film",
            Type = "Movie",
            MediaSources =
            [
                new MediaSourceInfo
                {
                    Id = "v1",
                    Name = "Director's Cut",
                    Size = 10L << 30,
                    Container = "mkv",
                    MediaStreams = [new MediaStream { Type = "Video", Codec = "hevc", Width = 3840, Height = 2160 }],
                },
                new MediaSourceInfo
                {
                    Id = "v2",
                    Size = (long)Math.Round(18.4 * (1L << 30)),
                    Container = "mp4",
                    MediaStreams =
                    [
                        new MediaStream { Type = "Video", Codec = "hevc", Width = 3840, Height = 2160 },
                        new MediaStream { Type = "Audio", Codec = "ac3", Channels = 6 },
                    ],
                },
            ],
        };
        var item = MediaMapper.FromDto(dto);
        Assert.Equal(2, item.Versions.Count);
        Assert.Equal("v1", item.Versions[0].Id);
        Assert.Equal("Director's Cut", item.Versions[0].Label);
        Assert.Equal("v2", item.Versions[1].Id);
        Assert.Equal("2160p HEVC · 18,4 Go", item.Versions[1].Label);
        Assert.Single(item.StreamsFor("v1"));
        Assert.Equal(2, item.StreamsFor("v2").Count);
    }
}

public class PlaybackTests
{
    private static readonly Uri Base = new("https://h.fr/jf");

    private static PlaybackInfoResponse Response(bool direct) => new()
    {
        PlaySessionId = "ps",
        MediaSources =
        [
            new MediaSourceInfo
            {
                Id = "src", ETag = "tag", SupportsDirectPlay = direct,
                TranscodingUrl = "/videos/i/master.m3u8?DeviceId=d&ApiKey=SECRET&MediaSourceId=src",
                DefaultAudioStreamIndex = 2, DefaultSubtitleStreamIndex = 5, RunTimeTicks = TimeSpan.FromHours(2).Ticks,
                MediaStreams =
                [
                    new MediaStream { Type = "Video", Index = 0, Codec = "hevc" },
                    new MediaStream { Type = "Audio", Index = 1, Codec = "eac3", Language = "eng", Channels = 6 },
                    new MediaStream { Type = "Audio", Index = 2, Codec = "ac3", Language = "fre", DisplayTitle = "Français 5.1" },
                    new MediaStream { Type = "Subtitle", Index = 4, Codec = "srt", Language = "fre", IsExternal = true },
                    new MediaStream { Type = "Subtitle", Index = 5, Codec = "pgssub", Language = "fre", IsForced = true },
                    new MediaStream { Type = "Subtitle", Index = 6, Codec = "ass", Language = "eng" },
                ],
            },
        ],
    };

    [Fact]
    public void LectureDirecte_urlStatiqueSansJeton()
    {
        var plan = PlaybackService.PlanFromResponse(Response(direct: true), "i", Base, TimeSpan.Zero);
        Assert.Equal(PlayMethod.DirectPlay, plan.Method);
        Assert.Equal("https://h.fr/jf/Videos/i/stream?static=true&mediaSourceId=src&playSessionId=ps&tag=tag", plan.StreamUrl.ToString());
        Assert.Equal(2, plan.AudioIndex);
        Assert.Equal(5, plan.SubtitleIndex);
        Assert.Equal("Français 5.1", plan.CurrentAudio?.Label);
        Assert.Equal("ENG · EAC3 · 6 can.", plan.AudioTracks[0].Label);
    }

    [Fact]
    public void Transcodage_cleApiRetireeDeLUrl()
    {
        var plan = PlaybackService.PlanFromResponse(Response(direct: false), "i", Base, TimeSpan.Zero);
        Assert.Equal(PlayMethod.Transcode, plan.Method);
        Assert.DoesNotContain("SECRET", plan.StreamUrl.ToString());
        Assert.Equal("https://h.fr/jf/videos/i/master.m3u8?DeviceId=d&MediaSourceId=src", plan.StreamUrl.ToString());
    }

    [Fact]
    public void RangsMpv_pistesIntegreesSeulement()
    {
        var plan = PlaybackService.PlanFromResponse(Response(direct: true), "i", Base, TimeSpan.Zero);
        Assert.Equal(2, plan.MpvId(plan.AudioTracks[1]));
        Assert.Null(plan.MpvId(plan.SubtitleTracks[0])); // externe
        Assert.Equal(1, plan.MpvId(plan.SubtitleTracks[1]));
        Assert.Equal(2, plan.MpvId(plan.SubtitleTracks[2]));
    }

    [Fact]
    public void LectureRefusee()
    {
        var e = Assert.Throws<ApiException>(() =>
            PlaybackService.PlanFromResponse(new PlaybackInfoResponse { ErrorCode = "NotAllowed" }, "i", Base, TimeSpan.Zero));
        Assert.Equal(ApiErrorKind.PlaybackDenied, e.Kind);
        Assert.Contains("pas autorisée", e.UserMessage);
    }

    [Fact]
    public void PreferencesDePistes()
    {
        var plan = PlaybackService.PlanFromResponse(Response(direct: true), "i", Base, TimeSpan.Zero);
        var settings = new AppSettings { AudioLanguage = "en", SubtitleMode = SubtitleMode.Always, SubtitleLanguage = "eng" };
        Assert.Equal((1, 6), TrackPreferences.Preferred(plan, settings));
        settings.SubtitleMode = SubtitleMode.ForcedOnly;
        settings.SubtitleLanguage = "fr";
        Assert.Equal((1, 5), TrackPreferences.Preferred(plan, settings));
        settings.SubtitleMode = SubtitleMode.None;
        Assert.Null(TrackPreferences.Preferred(plan, settings).Subtitle);
    }

    [Fact]
    public void PreferencesDePistes_depuisLaFiche()
    {
        // Pistes de la fiche (MediaSources) : même choix que sur le plan, sans requête PlaybackInfo de plus.
        var response = Response(direct: false);
        var plan = PlaybackService.PlanFromResponse(response, "i", Base, TimeSpan.Zero);
        var fromItem = PlaybackService.TracksOf(response.MediaSources![0]);
        foreach (var mode in new[] { SubtitleMode.Always, SubtitleMode.ForcedOnly, SubtitleMode.Server, SubtitleMode.None })
        {
            var settings = new AppSettings { AudioLanguage = "en", SubtitleMode = mode, SubtitleLanguage = "fr" };
            Assert.Equal(TrackPreferences.Preferred(plan, settings), TrackPreferences.Preferred(fromItem, settings));
        }
    }

    [Fact]
    public void Segments_etEpisodeSuivant()
    {
        var next = new MediaItem { Id = "n", Name = "Suite", Kind = MediaKind.Episode };
        var trickplay = new TrickplayManifest(320, 180, 10, 10, 250, TimeSpan.FromSeconds(10));
        Assert.Equal((0, 0, 0), trickplay.TileAt(TimeSpan.Zero));
        Assert.Equal((0, 3, 1), trickplay.TileAt(TimeSpan.FromSeconds(135)));
        Assert.Equal((1, 5, 0), trickplay.TileAt(TimeSpan.FromSeconds(1050)));
        // Au-delà de la dernière vignette : on reste dessus, sans demander une planche inexistante.
        Assert.Equal((2, 9, 4), trickplay.TileAt(TimeSpan.FromHours(10)));
        var chosen = PlaybackService.TrickplayFrom(new BaseItemDto
        {
            Trickplay = new()
            {
                ["source"] = new()
                {
                    ["160"] = new TrickplayInfoDto { Width = 160, Height = 90, Interval = 10000, ThumbnailCount = 10 },
                    ["320"] = new TrickplayInfoDto { Width = 320, Height = 180, TileWidth = 8, TileHeight = 6, Interval = 5000, ThumbnailCount = 40 },
                },
            },
        }, "source");
        Assert.Equal(new TrickplayManifest(320, 180, 8, 6, 40, TimeSpan.FromSeconds(5)), chosen);
        Assert.Null(PlaybackService.TrickplayFrom(new BaseItemDto(), "source"));

        var extras = new PlaybackExtras([],
            [
                new MediaSegment(SegmentType.Intro, TimeSpan.FromSeconds(60), TimeSpan.FromSeconds(150)),
                new MediaSegment(SegmentType.Recap, TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(12)),
                new MediaSegment(SegmentType.Outro, TimeSpan.FromMinutes(40), TimeSpan.FromMinutes(42)),
            ],
            next);
        Assert.Equal(SegmentType.Intro, extras.SkippableAt(TimeSpan.FromSeconds(90))?.Type);
        Assert.Null(extras.SkippableAt(TimeSpan.FromSeconds(149.5)));
        Assert.Null(extras.SkippableAt(TimeSpan.FromSeconds(11))); // moins de 3 s
        Assert.Null(extras.SkippableAt(TimeSpan.FromMinutes(41))); // générique : la carte « suivant » le remplace
        Assert.Equal(TimeSpan.FromMinutes(40), extras.UpNextAt(TimeSpan.FromMinutes(42)));
        var noOutro = extras with { Segments = [] };
        Assert.Equal(TimeSpan.FromMinutes(41.5), noOutro.UpNextAt(TimeSpan.FromMinutes(42)));
        Assert.Equal(TimeSpan.FromSeconds(30), noOutro.UpNextAt(TimeSpan.FromSeconds(60)));
    }

    [Fact]
    public void ProfilMpv_toutEnLectureDirecte()
    {
        var profile = PlaybackService.MpvDeviceProfile(120_000_000).ToJsonString();
        Assert.Contains("\"Container\":\"mkv,mp4", profile);
        Assert.Contains("\"Protocol\":\"hls\"", profile);
    }

    [Fact]
    public void PlanFromResponse_choisitLaSourceDemandee()
    {
        var response = new PlaybackInfoResponse
        {
            PlaySessionId = "ps",
            MediaSources =
            [
                new MediaSourceInfo { Id = "v1", ETag = "t1", SupportsDirectPlay = true },
                new MediaSourceInfo { Id = "v2", ETag = "t2", SupportsDirectPlay = true },
            ],
        };
        var plan = PlaybackService.PlanFromResponse(response, "i", Base, TimeSpan.Zero, mediaSourceId: "v2");
        Assert.Equal("v2", plan.MediaSourceId);
        Assert.Contains("mediaSourceId=v2", plan.StreamUrl.ToString());
        Assert.Contains("tag=t2", plan.StreamUrl.ToString());
        Assert.Equal("v1", PlaybackService.PlanFromResponse(response, "i", Base, TimeSpan.Zero).MediaSourceId);
    }
}

public class AccentTests
{
    private static byte[] Image(params (byte R, byte G, byte B, int Count)[] parts)
    {
        var data = new List<byte>();
        foreach (var (r, g, b, count) in parts)
            for (var i = 0; i < count; i++) data.AddRange([r, g, b, 255]);
        return [.. data];
    }

    [Fact]
    public void TeinteViveDominante_plutotQueMoyenne()
    {
        // Beaucoup de gris, un peu d'orange vif et moins de bleu : l'orange l'emporte.
        var accent = Accent.Dominant(Image((128, 128, 128, 400), (230, 120, 30, 120), (40, 80, 200, 60)));
        Assert.NotNull(accent);
        var (h, s, l) = Accent.ToHsl(accent.Value.R, accent.Value.G, accent.Value.B);
        Assert.InRange(h, 15, 45);
        Assert.InRange(l, 0.549, 0.721);
        Assert.InRange(s, 0.349, 0.851);
    }

    [Fact]
    public void ImageNeutre_pasDAccent() =>
        Assert.Null(Accent.Dominant(Image((20, 20, 20, 300), (200, 200, 200, 276))));

    [Fact]
    public void ConversionHsl_allerRetour()
    {
        var (h, s, l) = Accent.ToHsl(77, 163, 255);
        var back = Accent.FromHsl(h, s, l);
        Assert.Equal(new Rgb(77, 163, 255), back);
    }
}

[Collection("Localization")]
public class AppSettingsLocalizationTests
{
    [Fact]
    public void Langues_refletentLaLangueCouranteDynamiquement()
    {
        var previous = L.IsEnglish;
        try
        {
            L.IsEnglish = false;
            Assert.Equal("Français", AppSettings.Languages.First(l => l.Code == "fre").Name);
            Assert.Equal("Anglais", AppSettings.Languages.First(l => l.Code == "eng").Name);

            L.IsEnglish = true;
            Assert.Equal("French", AppSettings.Languages.First(l => l.Code == "fre").Name);
            Assert.Equal("English", AppSettings.Languages.First(l => l.Code == "eng").Name);
        }
        finally
        {
            L.IsEnglish = previous;
        }
    }
}

public class AppLogTests
{
    [Fact]
    public void Redact_masqueLesQuatreFormatsDeSecretsEtPreserveLeTextePropre()
    {
        Assert.Equal("MediaBrowser Client=\"OptiFin\", Token=\"***\"", AppLog.Redact("MediaBrowser Client=\"OptiFin\", Token=\"secret-123\""));
        Assert.Equal("https://s/v?api_key=***&k=2", AppLog.Redact("https://s/v?api_key=abc999&k=2"));
        Assert.Equal("X-Emby-Token: *** reste", AppLog.Redact("X-Emby-Token: tok-xyz reste"));
        Assert.Equal("{\"AccessToken\":\"***\",\"User\":\"alice\"}", AppLog.Redact("{\"AccessToken\":\"acc\",\"User\":\"alice\"}"));
        Assert.Equal("{\"Password\":\"***\"}", AppLog.Redact("{\"Password\":\"p@ss\"}"));

        const string clean = "GET /Users/u1/Items 200 (12 ms)";
        Assert.Same(clean, AppLog.Redact(clean));
    }

    [Fact]
    public void Add_borneLeJournalATroisMilleEntrees()
    {
        var tag = "cap-" + Guid.NewGuid().ToString("N");
        for (var i = 0; i < 3050; i++) AppLog.Add(LogLevel.Info, tag, $"m{i}");
        var snap = AppLog.Snapshot();
        Assert.Equal(3000, snap.Count);
        Assert.DoesNotContain(snap, e => e.Tag == tag && e.Message == "m0");
        Assert.Contains(snap, e => e.Tag == tag && e.Message == "m3049");
    }
}

public class MediaMapperExtrasTests
{
    [Fact]
    public void Clean_rapideEtSansHtml()
    {
        Assert.Null(MediaMapper.Clean(null));
        Assert.Null(MediaMapper.Clean("   \t\r\n "));
        Assert.Equal("Synopsis brut.", MediaMapper.Clean("  Synopsis brut.  "));
        Assert.Equal("A\n\"B\" & 'C'", MediaMapper.Clean("<p>A<br/>&quot;B&quot; &amp; &#39;C&#39;</p>"));
    }

    [Fact]
    public void MultiVersions_tracksEtPlanLocalParVersion()
    {
        var dto = new BaseItemDto
        {
            Id = "m1",
            Name = "Film",
            Type = "Movie",
            MediaSources =
            [
                new MediaSourceInfo
                {
                    Id = "v1",
                    DefaultAudioStreamIndex = 1,
                    DefaultSubtitleStreamIndex = 2,
                    MediaStreams =
                    [
                        new MediaStream { Type = "Audio", Index = 1, Codec = "aac", Language = "fre" },
                        new MediaStream { Type = "Subtitle", Index = 2, Codec = "srt", Language = "fre" },
                    ],
                },
                new MediaSourceInfo
                {
                    Id = "v2",
                    DefaultAudioStreamIndex = 3,
                    DefaultSubtitleStreamIndex = 5,
                    MediaStreams =
                    [
                        new MediaStream { Type = "Audio", Index = 3, Codec = "dts", Language = "eng" },
                        new MediaStream { Type = "Subtitle", Index = 4, Codec = "srt", Language = "eng", IsExternal = true },
                        new MediaStream { Type = "Subtitle", Index = 5, Codec = "ass", Language = "eng" },
                    ],
                },
            ],
        };

        var item = MediaMapper.FromDto(dto);
        Assert.Equal(3, item.TracksFor("v2")?.AudioIndex);
        Assert.Equal(1, item.TracksFor("unknown")?.AudioIndex);

        var plan = PlaybackService.LocalPlan(item, Path.Combine(Path.GetTempPath(), "v2.mkv"), TimeSpan.FromSeconds(15), "v2");
        Assert.Equal("v2", plan.MediaSourceId);
        Assert.Equal(3, plan.AudioIndex);
        Assert.Equal(5, plan.SubtitleIndex);
        Assert.Single(plan.SubtitleTracks); // externe filtré en lecture locale
    }

    [Fact]
    public void Trickplay_dimensionsNullesIgnoreesEtProtegees()
    {
        var manifest = new TrickplayManifest(320, 180, 0, 0, 10, TimeSpan.FromSeconds(5));
        Assert.Equal((2, 0, 0), manifest.TileAt(TimeSpan.FromSeconds(12)));

        var dto = new BaseItemDto
        {
            Trickplay = new()
            {
                ["src"] = new()
                {
                    ["bad"] = new TrickplayInfoDto { Width = 320, Interval = 5000, TileWidth = 0, TileHeight = 4, ThumbnailCount = 10 },
                    ["ok"] = new TrickplayInfoDto { Width = 160, Height = 90, Interval = 5000, TileWidth = 4, TileHeight = 4, ThumbnailCount = 10 },
                },
            },
        };
        var picked = PlaybackService.TrickplayFrom(dto, "src");
        Assert.NotNull(picked);
        Assert.Equal(160, picked.Width);

        dto.Trickplay["src"].Remove("ok");
        Assert.Null(PlaybackService.TrickplayFrom(dto, "src"));
    }
}

public sealed class HomeRepositoryTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "optifin-home-" + Guid.NewGuid().ToString("N"));
    private readonly HttpListener _listener = new();
    private readonly string _url;

    public HomeRepositoryTests()
    {
        Directory.CreateDirectory(_dir);
        for (var attempt = 0; attempt < 10; attempt++)
        {
            var port = 25_000 + Random.Shared.Next(2000);
            _url = $"http://127.0.0.1:{port}/";
            try
            {
                _listener.Prefixes.Clear();
                _listener.Prefixes.Add(_url);
                _listener.Start();
                _ = Task.Run(ServeAsync);
                return;
            }
            catch
            {
                _listener = new HttpListener();
            }
        }
        throw new InvalidOperationException("Port de test indisponible");
    }

    public void Dispose()
    {
        _listener.Abort();
        if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
    }

    private async Task ServeAsync()
    {
        while (_listener.IsListening)
        {
            HttpListenerContext c;
            try
            {
                c = await _listener.GetContextAsync();
            }
            catch
            {
                return;
            }
            _ = Task.Run(async () =>
            {
                try
                {
                    var path = c.Request.Url!.AbsolutePath;
                    var json = path switch
                    {
                        "/Users/u1/Views" => """{"Items":[{"Id":"lib1","Name":"Films","CollectionType":"movies"}]}""",
                        "/Users/u1/Items/Resume" => """{"Items":[{"Id":"r1","Name":"Reprise","Type":"Movie"}]}""",
                        "/Shows/NextUp" => """{"Items":[{"Id":"n1","Name":"Suite","Type":"Episode"}]}""",
                        "/Users/u1/Items/Latest" => """[{"Id":"l1","Name":"Récent","Type":"Movie"}]""",
                        "/Users/u1/Items" when c.Request.QueryString["IsFavorite"] == "true" =>
                            """{"Items":[{"Id":"fav1","Name":"Favori","Type":"Movie"}]}""",
                        "/Users/u1/Items" =>
                            """{"Items":[{"Id":"f1","Name":"Vedette","Type":"Movie","BackdropImageTags":["b1"]}]}""",
                        _ => "{}",
                    };
                    var bytes = Encoding.UTF8.GetBytes(json);
                    c.Response.ContentType = "application/json";
                    c.Response.ContentLength64 = bytes.Length;
                    await c.Response.OutputStream.WriteAsync(bytes);
                    c.Response.Close();
                }
                catch
                {
                    // Arrêt du serveur de test.
                }
            });
        }
    }

    [Fact]
    public async Task FetchAsync_chargeEnParallele_etClearCacheReinitialiseWatchAsync()
    {
        var ct = TestContext.Current.CancellationToken;
        var api = new JellyfinClient(new Uri(_url), new ClientIdentity("OptiFin", "Tests", "t", "1.0"), () => "secret");
        var media = new MediaRepository(api, "u1");

        // Parent fichier : évite toute écriture disque asynchrone pendant l'essai de ClearCache.
        var fileAsDir = Path.Combine(_dir, "not-a-dir");
        await File.WriteAllTextAsync(fileAsDir, "x", ct);
        var repo = new HomeRepository(media, "compte", Path.Combine(fileAsDir, "cache"));

        var snap = await repo.FetchAsync(ct);
        Assert.Equal("lib1", Assert.Single(snap.Views).Id);
        Assert.Equal("f1", Assert.Single(snap.Featured).Id);
        Assert.Equal("r1", Assert.Single(snap.Resume).Id);
        Assert.Equal("n1", Assert.Single(snap.NextUp).Id);
        Assert.Equal("fav1", Assert.Single(snap.Favorites).Id);
        Assert.Equal("l1", Assert.Single(snap.Latest["lib1"]).Id);

        var first = new List<HomeData>();
        await foreach (var d in repo.WatchAsync(ct)) first.Add(d);
        Assert.False(Assert.Single(first).FromCache);

        var second = new List<HomeData>();
        await foreach (var d in repo.WatchAsync(ct)) second.Add(d);
        Assert.Equal([true, false], second.Select(d => d.FromCache));

        repo.ClearCache();
        var afterClear = new List<HomeData>();
        await foreach (var d in repo.WatchAsync(ct)) afterClear.Add(d);
        Assert.False(Assert.Single(afterClear).FromCache);
    }
}
