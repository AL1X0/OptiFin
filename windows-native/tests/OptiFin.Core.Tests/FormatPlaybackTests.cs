using System.Diagnostics;
using System.Runtime.InteropServices;
using OptiFin.Mpv;

namespace OptiFin.Core.Tests;

/// <summary>
/// Formats exigeants lus par le vrai mpv de l'appli : HDR10 (HEVC et AV1 10 bits), HLG, son
/// multicanal E-AC3, AC3, DTS, TrueHD, FLAC 7.1. Vérifie ce que mpv détecte (courbe, primaires,
/// luminance de mastering, canaux, codec, débit) et que l'image part vers un écran SDR convertie
/// (et non en PQ brut, qui donnerait une image délavée). Fichiers générés par ffmpeg (requis).
/// </summary>
public partial class FormatPlaybackTests
{
    [LibraryImport("user32.dll", EntryPoint = "CreateWindowExW", StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint CreateWindowEx(int exStyle, string className, string title, uint style, int x, int y, int w, int h,
        nint parent, nint menu, nint instance, nint param);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DestroyWindow(nint hwnd);

    private const string Video = "-f lavfi -i testsrc2=size=1920x1080:rate=24:duration=6";
    private const string Hdr10X265 = "log-level=error:hdr10=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:" +
                                     "master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400";

    private static string Audio(string layout)
    {
        var channels = layout == "7.1" ? 8 : 6;
        var map = string.Join("|", Enumerable.Range(0, channels).Select(c => $"c{c}=c0"));
        return $"-f lavfi -i sine=frequency=300:duration=6 -filter_complex [1:a]pan={layout}|{map}[a] -map 0:v -map [a]";
    }

    /// <summary>Fichier de test (créé une fois dans le dossier temporaire), ou null sans ffmpeg.</summary>
    private static string? Sample(string name, string args)
    {
        var dir = Path.Combine(Path.GetTempPath(), "optifin-tests", "formats");
        var file = Path.Combine(dir, name);
        if (File.Exists(file)) return file;
        Directory.CreateDirectory(dir);
        try
        {
            using var p = Process.Start(new ProcessStartInfo("ffmpeg", $"-v error -y {args} \"{file}.tmp.mkv\"")
            { UseShellExecute = false, CreateNoWindow = true, RedirectStandardError = true });
            if (p is null) return null;
            var err = p.StandardError.ReadToEnd();
            if (!p.WaitForExit(180_000) || p.ExitCode != 0) throw new InvalidOperationException($"ffmpeg ({name}) : {err}");
        }
        catch (System.ComponentModel.Win32Exception)
        {
            return null;
        }
        File.Move(file + ".tmp.mkv", file);
        return file;
    }

    private sealed record Seen(string? Gamma, string? Primaries, string? MaxLuma, string? MaxCll, string? TargetGamma, string? PixelFormat,
        string? VideoCodec, string? AudioCodec, int Channels, double? VideoBitrate, string? Hwdec, int Dropped, string Errors);

    private static async Task<Seen> PlayAsync(string file)
    {
        var hwnd = CreateWindowEx(0, "STATIC", "mpv", 0x80000000, 0, 0, 960, 540, 0, 0, 0, 0);
        var errors = new List<string>();
        try
        {
            using var mpv = MpvPlayer.Create(hwnd);
            var started = false;
            var position = TimeSpan.Zero;
            mpv.FirstFrame += () => started = true;
            mpv.PositionChanged += p => position = p;
            mpv.Log += (level, prefix, text) =>
            {
                // Machine de test sans carte graphique : l'échec du décodage matériel (repli logiciel) n'est pas une erreur de lecture.
                if (level is "error" or "fatal" && prefix != "vd" && !prefix.StartsWith("ffmpeg")) lock (errors) errors.Add($"[{prefix}] {text}");
            };
            mpv.Load(file, new Dictionary<string, string>(), TimeSpan.Zero);
            var deadline = DateTime.UtcNow.AddSeconds(60);
            while (!(started && position > TimeSpan.FromSeconds(2.5)) && DateTime.UtcNow < deadline) await Task.Delay(50);
            Assert.True(started, $"{Path.GetFileName(file)} : aucune image ({string.Join(" | ", errors)})");
            Assert.True(position > TimeSpan.FromSeconds(2.5), $"{Path.GetFileName(file)} : la lecture n'avance pas ({position})");
            int.TryParse(mpv.Get("audio-params/channel-count"), out var channels);
            return new Seen(mpv.Get("video-params/gamma"), mpv.Get("video-params/primaries"), mpv.Get("video-params/max-luma"),
                mpv.Get("video-params/max-cll"), mpv.Get("video-target-params/gamma"), mpv.Get("video-params/hw-pixelformat") ?? mpv.Get("video-params/pixelformat"),
                mpv.Get("video-codec-name") ?? mpv.Get("video-format"), mpv.Get("audio-codec-name"), channels,
                // Comme le panneau d'infos : débit instantané, sinon moyen (taille / durée).
                mpv.GetDouble("video-bitrate") ?? mpv.GetDouble("file-size") * 8 / mpv.GetDouble("duration"),
                mpv.Get("hwdec-current"), mpv.DroppedFrames, string.Join(" | ", errors));
        }
        finally
        {
            DestroyWindow(hwnd);
        }
    }

    private static string RequireFfmpeg(string? file)
    {
        if (file is null) Assert.Skip("ffmpeg introuvable : pas de fichier de test.");
        return file;
    }

    [Fact]
    public async Task Hdr10_hevc_10bits_eac3_51()
    {
        var file = RequireFfmpeg(Sample("hdr10-eac3.mkv",
            $"{Video} {Audio("5.1")} -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le -x265-params \"{Hdr10X265}\" -c:a eac3 -b:a 640k"));
        var seen = await PlayAsync(file);
        Assert.Equal("pq", seen.Gamma);
        Assert.Equal("bt.2020", seen.Primaries);
        // Métadonnées de mastering (1000 nits) lues : nécessaires au bon calcul du rendu.
        Assert.Equal(1000, double.Parse(seen.MaxLuma!, System.Globalization.CultureInfo.InvariantCulture));
        // Écran SDR : image convertie (tone mapping), pas envoyée en PQ.
        Assert.NotEqual("pq", seen.TargetGamma);
        Assert.Equal("eac3", seen.AudioCodec);
        Assert.Equal(6, seen.Channels);
        Assert.True(seen.VideoBitrate > 0, "débit vidéo inconnu");
        Assert.Empty(seen.Errors);
    }

    [Fact]
    public async Task Hlg_hevc_ac3_51()
    {
        var file = RequireFfmpeg(Sample("hlg-ac3.mkv",
            $"{Video} {Audio("5.1")} -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le " +
            "-x265-params \"log-level=error:colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc\" -c:a ac3"));
        var seen = await PlayAsync(file);
        Assert.Equal("hlg", seen.Gamma);
        Assert.Equal("bt.2020", seen.Primaries);
        Assert.NotEqual("hlg", seen.TargetGamma);
        Assert.Equal("ac3", seen.AudioCodec);
        Assert.Equal(6, seen.Channels);
        Assert.Empty(seen.Errors);
    }

    [Fact]
    public async Task Av1_hdr10_flac_71()
    {
        var file = RequireFfmpeg(Sample("av1-hdr10-flac71.mkv",
            $"{Video} {Audio("7.1")} -c:v libsvtav1 -preset 12 -pix_fmt yuv420p10le " +
            "-svtav1-params \"color-primaries=9:transfer-characteristics=16:matrix-coefficients=9:" +
            "mastering-display=G(0.17,0.797)B(0.131,0.046)R(0.708,0.292)WP(0.3127,0.329)L(1000,0.0001):content-light=1000,400\" -c:a flac"));
        var seen = await PlayAsync(file);
        Assert.Equal("av1", seen.VideoCodec);
        Assert.Equal("pq", seen.Gamma);
        Assert.NotEqual("pq", seen.TargetGamma);
        Assert.Equal("flac", seen.AudioCodec);
        Assert.Equal(8, seen.Channels);
        Assert.Empty(seen.Errors);
    }

    [Fact]
    public async Task Dts_51()
    {
        var file = RequireFfmpeg(Sample("h264-dts.mkv",
            $"{Video} {Audio("5.1")} -c:v libx264 -preset ultrafast -c:a dca -strict -2 -b:a 1509k"));
        var seen = await PlayAsync(file);
        Assert.Equal("dts", seen.AudioCodec);
        Assert.Equal(6, seen.Channels);
        Assert.Empty(seen.Errors);
    }

    [Fact]
    public async Task TrueHd_multicanal()
    {
        var file = RequireFfmpeg(Sample("h264-truehd.mkv",
            $"{Video} {Audio("5.1")} -c:v libx264 -preset ultrafast -c:a truehd -strict -2"));
        var seen = await PlayAsync(file);
        Assert.Equal("truehd", seen.AudioCodec);
        Assert.Equal(6, seen.Channels);
        Assert.Empty(seen.Errors);
    }
}
