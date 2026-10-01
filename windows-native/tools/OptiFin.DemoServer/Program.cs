using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

// Serveur Jellyfin simulé : catalogue de démonstration et images générées. Sert aux captures
// et aux vérifications de l'appli Windows sans vrai serveur.
//
//   dotnet run --project tools/OptiFin.DemoServer [port]

var port = args.Length > 0 ? int.Parse(args[0]) : 8097;
var listener = new HttpListener();
listener.Prefixes.Add($"http://localhost:{port}/");
listener.Start();
Console.WriteLine($"Serveur de démonstration sur http://localhost:{port}");
var catalog = new Catalog();
while (true)
{
    var context = await listener.GetContextAsync();
    _ = Task.Run(() => Handle(context, catalog));
}

static void Handle(HttpListenerContext context, Catalog catalog)
{
    var request = context.Request;
    var path = request.Url!.AbsolutePath.Trim('/');
    var q = request.QueryString;
    try
    {
        if (path.StartsWith("Videos/") && path.EndsWith("/stream"))
        {
            // Vidéo de test non compressée (Y4M), générée une fois : lue par mpv comme un vrai fichier.
            var video = TestVideo.Bytes.Value;
            context.Response.ContentType = "video/x-yuv4mpeg";
            context.Response.ContentLength64 = video.Length;
            try { context.Response.OutputStream.Write(video); } catch (HttpListenerException) { }
            context.Response.Close();
            return;
        }
        if (path.Contains("/Images/"))
        {
            var bytes = Art.Render(path, q["maxWidth"]);
            if (bytes is null)
            {
                context.Response.StatusCode = 404;
            }
            else
            {
                context.Response.ContentType = "image/png";
                context.Response.OutputStream.Write(bytes);
            }
            context.Response.Close();
            return;
        }
        JsonNode? body = path switch
        {
            "System/Info/Public" => new JsonObject
            {
                ["Id"] = "demo-server", ["ServerName"] = "Maison", ["Version"] = "10.10.7", ["ProductName"] = "Jellyfin Server",
            },
            "Users/Public" => new JsonArray(User("u1", "Léa"), User("u2", "Hugo"), User("u3", "Enfants")),
            "QuickConnect/Enabled" => JsonValue.Create(true),
            "Users/AuthenticateByName" => new JsonObject { ["User"] = User("u1", "Léa"), ["AccessToken"] = "demo-token" },
            _ when path.EndsWith("/Views") => catalog.Result(catalog.Views),
            _ when path.EndsWith("/Items/Resume") => catalog.Result(catalog.Resume()),
            _ when path.EndsWith("/Items/Latest") => new JsonArray([.. catalog.Latest(q["ParentId"]).Select(i => (JsonNode?)i.DeepClone())]),
            "Shows/NextUp" => catalog.Result(catalog.NextUp(q["SeriesId"])),
            _ when path.StartsWith("Shows/") && path.EndsWith("/Seasons") => catalog.Result(catalog.Seasons(path.Split('/')[1])),
            _ when path.StartsWith("Shows/") && path.EndsWith("/Episodes") => catalog.Result(catalog.Episodes(path.Split('/')[1], q["SeasonId"], q["StartItemId"])),
            _ when path.StartsWith("Items/") && path.EndsWith("/Similar") => catalog.Result(catalog.Movies.Take(8)),
            _ when path.StartsWith("Items/") && path.EndsWith("/PlaybackInfo") => catalog.PlaybackInfo(path.Split('/')[1]),
            "Items/Filters2" => new JsonObject { ["Genres"] = new JsonArray([.. catalog.Genres.Select(g => (JsonNode?)new JsonObject { ["Id"] = g, ["Name"] = g })]) },
            "Items/Filters" => new JsonObject { ["Years"] = new JsonArray(2025, 2024, 2023, 2022) },
            "Persons" => catalog.Result([]),
            _ when path.StartsWith("MediaSegments/") => new JsonObject { ["Items"] = new JsonArray() },
            _ when path.StartsWith("Sessions/") => null,
            _ when path.StartsWith("Users/") && path.Contains("/Items/") && !path.EndsWith("/Items") => catalog.Find(path.Split('/')[^1]),
            _ when path.EndsWith("/Items") => catalog.Query(q),
            _ => null,
        };
        context.Response.ContentType = "application/json";
        if (body != null) context.Response.OutputStream.Write(Encoding.UTF8.GetBytes(body.ToJsonString()));
        else context.Response.StatusCode = path.StartsWith("Sessions/") ? 204 : 404;
    }
    catch (Exception e)
    {
        Console.WriteLine($"{path} : {e.Message}");
        context.Response.StatusCode = 500;
    }
    context.Response.Close();
}

static JsonObject User(string id, string name) => new() { ["Id"] = id, ["Name"] = name, ["HasPassword"] = true };

sealed record Title(string Id, string Name, string Type, int Scene, string[] Genres, int Minutes, double Rating, int Year,
    string Overview, string Tagline, double Progress = 0, bool Favorite = false, string Quality = "4K DV", int Seasons = 0);

sealed class Catalog
{
    public readonly List<JsonObject> Movies = [];
    public readonly List<JsonObject> Series = [];
    public readonly List<JsonObject> Views = [];
    public readonly Dictionary<string, List<JsonObject>> SeasonsOf = [];
    public readonly Dictionary<string, List<JsonObject>> EpisodesOf = [];
    public readonly string[] Genres = ["Aventure", "Drame", "Science-fiction", "Thriller", "Animation", "Comédie"];

    private static readonly Title[] Titles =
    [
        new("horizon", "Horizon perdu", "Movie", 0, ["Science-fiction", "Aventure"], 134, 7.9, 2025,
            "Échouée sur une planète désertique après un saut raté, une pilote cartographe n’a que la course de deux soleils pour retrouver le signal de son vaisseau avant la grande nuit.",
            "Deux soleils. Un seul retour possible.", Favorite: true),
        new("marees", "Les Marées d’Orion", "Movie", 1, ["Drame", "Science-fiction"], 118, 7.4, 2024,
            "Sur une station océanique isolée, une biologiste découvre que les marées suivent un motif qui n’a rien de naturel. Et qu’il semble lui répondre.",
            "L’océan se souvient de tout.", Progress: 0.42, Quality: "4K HDR10"),
        new("neon", "Ville néon", "Movie", 2, ["Thriller"], 112, 7.1, 2023,
            "Une enquêtrice traque un pirate qui efface les souvenirs des habitants d’une mégapole qui ne dort jamais.",
            "La ville ne dort jamais. Elle observe."),
        new("sommet", "Le Dernier Sommet", "Movie", 3, ["Aventure", "Drame"], 126, 7.6, 2024,
            "Trois alpinistes tentent une dernière ascension hivernale, là où personne n’est jamais revenu.",
            "Certaines montagnes se méritent."),
        new("brume", "Brume", "Movie", 4, ["Thriller", "Drame"], 101, 6.9, 2024,
            "Un garde forestier découvre qu’un sentier disparu réapparaît chaque nuit de brouillard.",
            "Ne quittez pas le sentier.", Progress: 0.18, Quality: "1080p"),
        new("nebuleuse", "Nébuleuse", "Movie", 5, ["Science-fiction", "Animation"], 97, 7.8, 2025,
            "Une petite exploratrice robot traverse une nébuleuse pour rallumer une étoile éteinte.",
            "Au-delà de la lumière, il y a nous.", Favorite: true),
        new("minuit", "Soleil de minuit", "Movie", 6, ["Drame"], 109, 7.0, 2022,
            "Pendant l’été arctique, deux frères se retrouvent après dix ans pour vendre la maison familiale.",
            "Le jour ne se couche jamais.", Quality: "4K HDR10"),
        new("canyons", "L’Écho des canyons", "Movie", 0, ["Aventure", "Comédie"], 104, 6.8, 2023,
            "Une équipe de radio amateur part enregistrer l’écho le plus long du monde.",
            "Écoutez bien.", Quality: "1080p"),
        new("aurore", "Aurore boréale", "Movie", 7, ["Drame", "Comédie"], 99, 7.2, 2024,
            "Une astronome et un chauffeur de bus partagent une nuit à chercher les aurores.",
            "Le ciel s’allume pour vous."),
        new("tempete", "Avis de tempête", "Movie", 8, ["Thriller"], 115, 7.3, 2025,
            "Coincés dans un phare pendant la tempête du siècle, six inconnus réalisent que l’un d’eux ment.",
            "Personne ne sortira avant l’aube."),
        new("veilleurs", "Les Veilleurs", "Series", 7, ["Science-fiction", "Thriller"], 52, 8.2, 2023,
            "Dans une base polaire, une équipe surveille un signal venu des étoiles. Chaque nuit, il change.",
            "Quelqu’un écoute.", Seasons: 2, Favorite: true),
        new("kepler", "Station Kepler", "Series", 5, ["Science-fiction", "Drame"], 45, 7.7, 2024,
            "À bord d’une station en orbite autour d’une exoplanète, une équipage se prépare au premier atterrissage.",
            "Le prochain monde commence ici.", Seasons: 1),
    ];

    public Catalog()
    {
        Views.Add(new JsonObject { ["Id"] = "lib-films", ["Name"] = "Films", ["Type"] = "CollectionFolder", ["CollectionType"] = "movies", ["ImageTags"] = Tags("lib-films") });
        Views.Add(new JsonObject { ["Id"] = "lib-series", ["Name"] = "Séries", ["Type"] = "CollectionFolder", ["CollectionType"] = "tvshows", ["ImageTags"] = Tags("lib-series") });
        foreach (var t in Titles)
        {
            var item = Item(t);
            if (t.Type == "Movie") Movies.Add(item);
            else
            {
                Series.Add(item);
                var seasons = new List<JsonObject>();
                for (var s = 1; s <= t.Seasons; s++)
                {
                    var seasonId = $"{t.Id}-s{s}";
                    seasons.Add(new JsonObject
                    {
                        ["Id"] = seasonId, ["Name"] = $"Saison {s}", ["Type"] = "Season", ["SeriesId"] = t.Id, ["SeriesName"] = t.Name,
                        ["IndexNumber"] = s, ["ImageTags"] = Tags(t.Id),
                    });
                    var episodes = new List<JsonObject>();
                    for (var e = 1; e <= 6; e++)
                    {
                        var watched = s == 1 && e <= 2;
                        var progress = s == 1 && e == 3 ? 35.0 : 0;
                        episodes.Add(new JsonObject
                        {
                            ["Id"] = $"{seasonId}e{e}", ["Name"] = EpisodeName(e), ["Type"] = "Episode", ["SeriesId"] = t.Id, ["SeriesName"] = t.Name,
                            ["SeasonId"] = seasonId, ["IndexNumber"] = e, ["ParentIndexNumber"] = s,
                            ["Overview"] = "Le signal change de fréquence. L’équipe doit choisir : répondre ou se taire.",
                            ["RunTimeTicks"] = TimeSpan.FromMinutes(t.Minutes).Ticks, ["PremiereDate"] = new DateTime(t.Year, 3, e * 4).ToString("o"),
                            ["ImageTags"] = Tags($"{seasonId}e{e}"), ["SeriesPrimaryImageTag"] = "p", ["ParentBackdropItemId"] = t.Id,
                            ["ParentBackdropImageTags"] = new JsonArray("b"),
                            ["UserData"] = new JsonObject { ["Played"] = watched, ["PlayedPercentage"] = progress, ["PlaybackPositionTicks"] = (long)(TimeSpan.FromMinutes(t.Minutes).Ticks * progress / 100) },
                        });
                    }
                    EpisodesOf[seasonId] = episodes;
                }
                SeasonsOf[t.Id] = seasons;
                item["ChildCount"] = t.Seasons;
            }
        }
    }

    private static string EpisodeName(int e) => e switch
    {
        1 => "Le signal", 2 => "Interférences", 3 => "Veille", 4 => "La réponse", 5 => "Silence radio", _ => "Aube polaire",
    };

    private static JsonObject Tags(string id) => new() { ["Primary"] = "p", ["Thumb"] = "t", ["Logo"] = "l" };

    private static JsonObject Item(Title t)
    {
        var (w, h, range) = t.Quality switch
        {
            "1080p" => (1920, 1040, "SDR"),
            "4K HDR10" => (3840, 2076, "HDR10"),
            _ => (3840, 2076, "DOVIWithHDR10"),
        };
        return new JsonObject
        {
            ["Id"] = t.Id, ["Name"] = t.Name, ["Type"] = t.Type, ["Overview"] = t.Overview, ["Taglines"] = new JsonArray(t.Tagline),
            ["ProductionYear"] = t.Year, ["PremiereDate"] = new DateTime(t.Year, 5, 1).ToString("o"),
            ["Status"] = t.Type == "Series" ? "Continuing" : null,
            ["RunTimeTicks"] = TimeSpan.FromMinutes(t.Minutes).Ticks, ["CommunityRating"] = t.Rating, ["OfficialRating"] = "12",
            ["GenreItems"] = new JsonArray([.. t.Genres.Select(g => (JsonNode?)new JsonObject { ["Id"] = g, ["Name"] = g })]),
            ["Studios"] = new JsonArray(new JsonObject { ["Id"] = "s", ["Name"] = "Productions OptiFin" }),
            ["People"] = new JsonArray(
                new JsonObject { ["Id"] = "p1", ["Name"] = "Camille Arnaud", ["Type"] = "Director" },
                new JsonObject { ["Id"] = "p2", ["Name"] = "Inès Moreau", ["Role"] = "Commandante Vega", ["Type"] = "Actor" },
                new JsonObject { ["Id"] = "p3", ["Name"] = "Hugo Lambert", ["Role"] = "Ilan", ["Type"] = "Actor" },
                new JsonObject { ["Id"] = "p4", ["Name"] = "Sara Benali", ["Role"] = "Docteure Keller", ["Type"] = "Actor" }),
            ["UserData"] = new JsonObject
            {
                ["IsFavorite"] = t.Favorite, ["PlayedPercentage"] = t.Progress * 100,
                ["PlaybackPositionTicks"] = (long)(TimeSpan.FromMinutes(t.Minutes).Ticks * t.Progress),
                ["UnplayedItemCount"] = t.Type == "Series" ? 4 : null,
            },
            ["ImageTags"] = Tags(t.Id), ["BackdropImageTags"] = new JsonArray("b"),
            ["MediaStreams"] = new JsonArray(
                new JsonObject { ["Type"] = "Video", ["Codec"] = "hevc", ["Width"] = w, ["Height"] = h, ["VideoRangeType"] = range },
                new JsonObject { ["Type"] = "Audio", ["Codec"] = "eac3", ["Channels"] = 6, ["AudioSpatialFormat"] = t.Quality == "4K DV" ? "DolbyAtmos" : "None" }),
        };
    }

    public JsonObject Result(IEnumerable<JsonObject> items)
    {
        var list = items.ToList();
        return new JsonObject { ["Items"] = new JsonArray([.. list.Select(i => (JsonNode?)i.DeepClone())]), ["TotalRecordCount"] = list.Count };
    }

    public IEnumerable<JsonObject> All => Movies.Concat(Series).Concat(EpisodesOf.Values.SelectMany(e => e));

    public IEnumerable<JsonObject> Resume() =>
        Movies.Where(m => (double?)m["UserData"]!["PlayedPercentage"] > 0)
            .Concat(EpisodesOf.Values.SelectMany(e => e).Where(e => (double?)e["UserData"]!["PlayedPercentage"] > 0));

    public IEnumerable<JsonObject> NextUp(string? seriesId) =>
        EpisodesOf.Values.SelectMany(e => e)
            .Where(e => (seriesId == null || (string?)e["SeriesId"] == seriesId) && !(bool)e["UserData"]!["Played"]!)
            .GroupBy(e => (string?)e["SeriesId"]).Select(g => g.First());

    public IEnumerable<JsonObject> Latest(string? parentId) => parentId == "lib-series" ? Series : Movies.AsEnumerable().Reverse();
    public IEnumerable<JsonObject> Seasons(string id) => SeasonsOf.GetValueOrDefault(id) ?? [];

    public IEnumerable<JsonObject> Episodes(string seriesId, string? seasonId, string? startItemId)
    {
        var all = SeasonsOf.GetValueOrDefault(seriesId)?.SelectMany(s => EpisodesOf[(string)s["Id"]!]).ToList() ?? [];
        if (startItemId != null) return all.SkipWhile(e => (string?)e["Id"] != startItemId).Take(2);
        return seasonId == null ? all : all.Where(e => (string?)e["SeasonId"] == seasonId);
    }

    public JsonObject? Find(string id) => (JsonObject?)All.FirstOrDefault(i => (string?)i["Id"] == id)?.DeepClone();

    public JsonObject Query(System.Collections.Specialized.NameValueCollection q)
    {
        IEnumerable<JsonObject> items = All;
        if (q["Ids"] is { } ids) items = All.Where(i => ids.Split(',').Contains((string?)i["Id"]));
        else if (q["SearchTerm"] is { } term) items = All.Where(i => ((string?)i["Name"])!.Contains(term, StringComparison.OrdinalIgnoreCase));
        else if (q["IsFavorite"] == "true") items = Movies.Concat(Series).Where(i => (bool?)i["UserData"]!["IsFavorite"] == true);
        else if (q["ParentId"] == "lib-series") items = Series;
        else if (q["ParentId"] == "lib-films") items = Movies;
        else if (q["SortBy"] == "Random") items = Movies.Concat(Series).Where(i => (double?)i["UserData"]!["PlayedPercentage"] == 0);
        if (q["IncludeItemTypes"] is { } types && q["Ids"] == null)
            items = items.Where(i => types.Split(',').Contains((string?)i["Type"]));
        if (q["SortBy"]?.StartsWith("SortName") == true) items = items.OrderBy(i => (string?)i["Name"]);
        var list = items.ToList();
        var start = int.TryParse(q["StartIndex"], out var s) ? s : 0;
        var limit = int.TryParse(q["Limit"], out var l) ? l : 200;
        var page = list.Skip(start).Take(limit);
        var result = Result(page);
        result["TotalRecordCount"] = list.Count;
        return result;
    }

    public JsonObject PlaybackInfo(string id) => new()
    {
        ["PlaySessionId"] = "demo",
        ["MediaSources"] = new JsonArray(new JsonObject
        {
            ["Id"] = id, ["Container"] = "mkv", ["Bitrate"] = 42_000_000, ["SupportsDirectPlay"] = true, ["SupportsDirectStream"] = true,
            ["DefaultAudioStreamIndex"] = 1, ["RunTimeTicks"] = TimeSpan.FromMinutes(120).Ticks,
            ["MediaStreams"] = new JsonArray(
                new JsonObject { ["Type"] = "Video", ["Index"] = 0, ["Codec"] = "hevc", ["VideoRangeType"] = "HDR10" },
                new JsonObject { ["Type"] = "Audio", ["Index"] = 1, ["Codec"] = "eac3", ["Language"] = "fre", ["DisplayTitle"] = "Français - Dolby Digital+ 5.1", ["Channels"] = 6 },
                new JsonObject { ["Type"] = "Audio", ["Index"] = 2, ["Codec"] = "truehd", ["Language"] = "eng", ["DisplayTitle"] = "Anglais - TrueHD Atmos 7.1", ["Channels"] = 8 },
                new JsonObject { ["Type"] = "Subtitle", ["Index"] = 3, ["Codec"] = "subrip", ["Language"] = "fre", ["DisplayTitle"] = "Français (forcés)", ["IsForced"] = true },
                new JsonObject { ["Type"] = "Subtitle", ["Index"] = 4, ["Codec"] = "pgssub", ["Language"] = "fre", ["DisplayTitle"] = "Français - PGS" }),
        }),
    };
}

/// <summary>Illustrations générées : dégradés de « ciel », astre, silhouette du relief, titre.</summary>
static class Art
{
    private static readonly (Color Top, Color Bottom, Color Sun)[] Palettes =
    [
        (Color.FromArgb(60, 28, 40), Color.FromArgb(150, 80, 50), Color.FromArgb(255, 210, 140)),
        (Color.FromArgb(14, 22, 48), Color.FromArgb(40, 80, 130), Color.FromArgb(230, 240, 255)),
        (Color.FromArgb(30, 10, 50), Color.FromArgb(120, 30, 120), Color.FromArgb(80, 220, 255)),
        (Color.FromArgb(40, 60, 90), Color.FromArgb(200, 140, 110), Color.FromArgb(255, 230, 190)),
        (Color.FromArgb(25, 40, 35), Color.FromArgb(110, 140, 120), Color.FromArgb(245, 240, 210)),
        (Color.FromArgb(20, 10, 40), Color.FromArgb(70, 40, 140), Color.FromArgb(200, 170, 255)),
        (Color.FromArgb(60, 40, 70), Color.FromArgb(240, 160, 90), Color.FromArgb(255, 240, 200)),
        (Color.FromArgb(8, 20, 30), Color.FromArgb(20, 90, 90), Color.FromArgb(120, 255, 200)),
        (Color.FromArgb(30, 34, 40), Color.FromArgb(90, 100, 110), Color.FromArgb(220, 220, 230)),
    ];

    private static readonly string[] Names =
        ["horizon", "marees", "neon", "sommet", "brume", "nebuleuse", "minuit", "canyons", "aurore", "tempete", "veilleurs", "kepler"];

    private static readonly Dictionary<string, string> TitlesById = new()
    {
        ["horizon"] = "HORIZON PERDU", ["marees"] = "Les Marées d’Orion", ["neon"] = "VILLE NÉON", ["sommet"] = "LE DERNIER SOMMET",
        ["brume"] = "Brume", ["nebuleuse"] = "NÉBULEUSE", ["minuit"] = "Soleil de minuit", ["canyons"] = "L’ÉCHO DES CANYONS",
        ["aurore"] = "Aurore boréale", ["tempete"] = "AVIS DE TEMPÊTE", ["veilleurs"] = "LES VEILLEURS", ["kepler"] = "STATION KEPLER",
        ["lib-films"] = "FILMS", ["lib-series"] = "SÉRIES",
    };

    public static byte[]? Render(string path, string? maxWidth)
    {
        // Items/{id}/Images/{type}[/index]
        var parts = path.Split('/');
        var id = parts[1];
        var type = parts[3];
        var root = id.Split('-')[0];
        var scene = Array.IndexOf(Names, root);
        if (id.StartsWith("lib-")) scene = id == "lib-films" ? 0 : 7;
        if (scene < 0) scene = Math.Abs(id.GetHashCode()) % Palettes.Length;
        var palette = Palettes[scene % Palettes.Length];
        var title = TitlesById.GetValueOrDefault(root) ?? TitlesById.GetValueOrDefault(id);
        var width = int.TryParse(maxWidth, out var w) ? Math.Min(w, 1920) : 640;
        return type switch
        {
            "Primary" when id.Contains("e") && id.Contains("-s") => Scene(width, width * 9 / 16, palette, null, id.GetHashCode()),
            "Primary" => Scene(width, width * 3 / 2, palette, title, scene),
            "Logo" when title != null => Logo(width, title),
            "Logo" => null,
            _ => Scene(width, width * 9 / 16, palette, id.StartsWith("lib-") ? title : null, scene),
        };
    }

    private static byte[] Scene(int width, int height, (Color Top, Color Bottom, Color Sun) p, string? title, int seed)
    {
        using var bmp = new Bitmap(width, height);
        using var g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        using (var sky = new LinearGradientBrush(new Rectangle(0, 0, width, height), p.Top, p.Bottom, 90f)) g.FillRectangle(sky, 0, 0, width, height);
        var rnd = new Random(seed);
        var sun = height * 0.16f;
        using (var glow = new SolidBrush(Color.FromArgb(230, p.Sun)))
            g.FillEllipse(glow, width * (0.55f + (float)rnd.NextDouble() * 0.25f), height * 0.32f, sun, sun);
        using var land = new SolidBrush(Color.FromArgb(235, p.Top.R / 2, p.Top.G / 2, p.Top.B / 2));
        var points = new List<PointF> { new(0, height) };
        for (var x = 0; x <= 12; x++) points.Add(new PointF(width * x / 12f, height * (0.62f + (float)rnd.NextDouble() * 0.14f)));
        points.Add(new PointF(width, height));
        g.FillPolygon(land, points.ToArray());
        if (title != null)
        {
            using var font = new Font("Segoe UI", Math.Max(10, width / 11f), FontStyle.Bold);
            using var white = new SolidBrush(Color.White);
            var format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            g.DrawString(title, font, white, new RectangleF(width * 0.06f, height * 0.55f, width * 0.88f, height * 0.4f), format);
        }
        return Png(bmp);
    }

    private static byte[] Logo(int width, string title)
    {
        var height = width / 3;
        using var bmp = new Bitmap(width, height);
        using var g = Graphics.FromImage(bmp);
        g.Clear(Color.Transparent);
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        // Une seule ligne, réduite jusqu'à tenir dans la largeur.
        var size = height / 2.2f;
        Font font;
        while (true)
        {
            font = new Font("Segoe UI", size, FontStyle.Bold);
            if (g.MeasureString(title, font).Width <= width || size < 8) break;
            font.Dispose();
            size *= 0.9f;
        }
        using var white = new SolidBrush(Color.White);
        var format = new StringFormat(StringFormatFlags.NoWrap) { Alignment = StringAlignment.Near, LineAlignment = StringAlignment.Center };
        g.DrawString(title, font, white, new RectangleF(0, 0, width, height), format);
        font.Dispose();
        return Png(bmp);
    }

    private static byte[] Png(Bitmap bmp)
    {
        using var ms = new MemoryStream();
        bmp.Save(ms, ImageFormat.Png);
        return ms.ToArray();
    }
}


static class TestVideo
{
    public static readonly Lazy<byte[]> Bytes = new(Build);

    private static byte[] Build()
    {
        const int w = 320, h = 180, fps = 24, seconds = 40;
        using var ms = new MemoryStream();
        var header = Encoding.ASCII.GetBytes($"YUV4MPEG2 W{w} H{h} F{fps}:1 Ip A1:1 C420jpeg\n");
        ms.Write(header);
        var frame = new byte[w * h * 3 / 2];
        for (var n = 0; n < fps * seconds; n++)
        {
            ms.Write(Encoding.ASCII.GetBytes("FRAME\n"));
            for (var y = 0; y < h; y++)
                for (var x = 0; x < w; x++)
                    frame[y * w + x] = (byte)(40 + (x + n * 3) % 160 * y / h);
            var u = w * h;
            for (var y = 0; y < h / 2; y++)
                for (var x = 0; x < w / 2; x++)
                {
                    frame[u + y * (w / 2) + x] = (byte)(128 + 40 * Math.Sin((x + n) / 20.0));
                    frame[u + w * h / 4 + y * (w / 2) + x] = (byte)(128 + 40 * Math.Cos((y + n) / 15.0));
                }
            ms.Write(frame);
        }
        return ms.ToArray();
    }
}
