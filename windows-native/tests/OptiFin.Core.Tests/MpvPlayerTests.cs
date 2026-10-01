using System.Runtime.InteropServices;
using OptiFin.Mpv;

namespace OptiFin.Core.Tests;

/// <summary>Lecteur libmpv réel : fenêtre Windows, rendu Direct3D 11 (logiciel sur une machine sans GPU).</summary>
public partial class MpvPlayerTests
{
    [LibraryImport("user32.dll", EntryPoint = "CreateWindowExW", StringMarshalling = StringMarshalling.Utf16)]
    private static partial nint CreateWindowEx(int exStyle, string className, string title, uint style, int x, int y, int w, int h,
        nint parent, nint menu, nint instance, nint param);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DestroyWindow(nint hwnd);

    private static async Task Until(Func<bool> ok, string what, int seconds = 15)
    {
        var deadline = DateTime.UtcNow.AddSeconds(seconds);
        while (!ok())
        {
            if (DateTime.UtcNow > deadline) Assert.Fail($"Délai dépassé : {what}");
            await Task.Delay(50);
        }
    }

    [Fact]
    public async Task Lecture_position_pause_recherche_fin()
    {
        var hwnd = CreateWindowEx(0, "STATIC", "mpv", 0x80000000 /* WS_POPUP */, 0, 0, 640, 360, 0, 0, 0, 0);
        Assert.NotEqual(0, hwnd);
        using var player = MpvPlayer.Create(hwnd);
        TimeSpan position = default, duration = default;
        bool loaded = false, firstFrame = false, paused = true;
        EndReason? ended = null;
        int width = 0;
        player.FileLoaded += () => loaded = true;
        player.FirstFrame += () => firstFrame = true;
        player.PositionChanged += p => position = p;
        player.DurationChanged += d => duration = d;
        player.PauseChanged += p => paused = p;
        player.VideoSizeChanged += (w, _) => width = w;
        player.Ended += (r, _) => ended = r;

        player.Load("av://lavfi:testsrc2=size=640x360:rate=30:duration=4", new Dictionary<string, string>(), TimeSpan.FromSeconds(1));
        await Until(() => loaded && firstFrame, "ouverture");
        await Until(() => duration > TimeSpan.Zero, "durée");
        // Mire lavfi : la durée n'est qu'estimée (quelques dixièmes de seconde au tout début) ; seule sa
        // présence compte ici, la lecture jusqu'à la fin est vérifiée plus bas.
        await Until(() => width == 640, "taille");
        await Until(() => position > TimeSpan.FromSeconds(1.3), "lecture depuis 1 s");
        Assert.False(paused);

        player.Pause();
        await Until(() => paused, "pause");
        player.Seek(TimeSpan.FromSeconds(3));
        await Until(() => Math.Abs((position - TimeSpan.FromSeconds(3)).TotalSeconds) < 0.2, "recherche");
        player.Play();
        await Until(() => ended != null, "fin");
        Assert.Equal(EndReason.Eof, ended);
        DestroyWindow(hwnd);
    }

    [Fact]
    public async Task FichierIntrouvable_erreur()
    {
        var hwnd = CreateWindowEx(0, "STATIC", "mpv", 0x80000000, 0, 0, 320, 180, 0, 0, 0, 0);
        using var player = MpvPlayer.Create(hwnd);
        EndReason? ended = null;
        player.Ended += (r, _) => ended = r;
        player.Load(new Uri("file:///C:/introuvable/film.mkv"), new Dictionary<string, string>(), TimeSpan.Zero);
        await Until(() => ended != null, "échec");
        Assert.Equal(EndReason.Error, ended);
        DestroyWindow(hwnd);
    }
}
