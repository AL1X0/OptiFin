using Microsoft.UI.Composition;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using WinRT;

namespace OptiFin.App.Player;

/// <summary>
/// Fond de fenêtre entièrement transparent : là où l'interface ne dessine rien, Windows montre ce
/// qui est derrière — ici, la fenêtre vidéo de mpv.
/// </summary>
internal sealed partial class TransparentBackdrop : SystemBackdrop
{
    private static Windows.UI.Composition.Compositor? _compositor;
    private static object? _dispatcher;

    protected override void OnTargetConnected(ICompositionSupportsSystemBackdrop connectedTarget, XamlRoot xamlRoot)
    {
        base.OnTargetConnected(connectedTarget, xamlRoot);
        // Le compositeur « système » a besoin d'une file de répartition Windows sur ce thread.
        _dispatcher ??= Windows.System.DispatcherQueue.GetForCurrentThread() ?? (object)CreateDispatcherQueue();
        _compositor ??= new Windows.UI.Composition.Compositor();
        connectedTarget.SystemBackdrop = _compositor.CreateColorBrush(Windows.UI.Color.FromArgb(0, 0, 0, 0));
    }

    protected override void OnTargetDisconnected(ICompositionSupportsSystemBackdrop disconnectedTarget)
    {
        base.OnTargetDisconnected(disconnectedTarget);
        disconnectedTarget.SystemBackdrop = null;
    }

    private static Windows.System.DispatcherQueueController CreateDispatcherQueue()
    {
        var options = new DispatcherQueueOptions { Size = System.Runtime.InteropServices.Marshal.SizeOf<DispatcherQueueOptions>(), ThreadType = 2, ApartmentType = 2 };
        CreateDispatcherQueueController(options, out var raw);
        return Windows.System.DispatcherQueueController.FromAbi(raw);
    }

    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    private struct DispatcherQueueOptions
    {
        public int Size;
        public int ThreadType;
        public int ApartmentType;
    }

    [System.Runtime.InteropServices.DllImport("CoreMessaging.dll")]
    private static extern int CreateDispatcherQueueController(DispatcherQueueOptions options, out nint controller);
}
