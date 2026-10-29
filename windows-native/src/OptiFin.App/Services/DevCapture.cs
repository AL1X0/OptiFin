using Microsoft.UI.Xaml;
using OptiFin.Core.Logging;

namespace OptiFin.App.Services;

/// <summary>
/// Outil de développement : <c>OptiFin.exe --capture dossier [étapes]</c> prend des captures
/// successives de la fenêtre (sans dépendre de l'affichage du bureau) puis ferme l'appli.
/// Étapes : <c>nom=attente_ms</c> ou <c>nom=page:Section</c> (navigation avant capture).
/// </summary>
public static class DevCapture
{
    public static void AttachIfRequested(Window window, FrameworkElement root)
    {
        var args = Environment.GetCommandLineArgs();
        var i = Array.IndexOf(args, "--capture");
        if (i < 0 || i + 1 >= args.Length) return;
        var folder = args[i + 1];
        var steps = args.Skip(i + 2).ToList();
        if (steps.Count == 0) steps.Add("ecran=2500");
        // Contenu construit après l'écran de démarrage : la racine peut déjà être chargée.
        if (root.IsLoaded) _ = RunAsync();
        else root.Loaded += (_, _) => _ = RunAsync();

        async Task RunAsync()
        {
            foreach (var step in steps)
            {
                var (name, action) = step.Split('=', 2) is [var n, var a] ? (n, a) : (step, "2500");
                try
                {
                    if (int.TryParse(action, out var ms))
                    {
                        await Task.Delay(ms);
                    }
                    else
                    {
                        await DevActions.RunAsync(action);
                        await Task.Delay(2500);
                    }
                    var target = Player.PlayerLauncher.CurrentRoot ?? root;
                    await LoadImagesAsync(target);
                    await Capture.SaveAsync(target, Path.Combine(folder, name + ".png"));
                }
                catch (Exception e)
                {
                    AppLog.Error("capture", $"Capture « {name} » impossible", e);
                }
            }
            window.Close();
        }
    }

    private static readonly HttpClient Http = new();

    /// <summary>
    /// Images réseau de la page chargées tout de suite : sans bureau affiché (session déconnectée),
    /// Windows ne les télécharge jamais et la capture n'aurait que des cases vides.
    /// </summary>
    private static async Task LoadImagesAsync(Microsoft.UI.Xaml.DependencyObject root)
    {
        var images = new List<Microsoft.UI.Xaml.Controls.Image>();
        void Walk(Microsoft.UI.Xaml.DependencyObject node)
        {
            if (node is Microsoft.UI.Xaml.Controls.Image image) images.Add(image);
            for (var i = 0; i < Microsoft.UI.Xaml.Media.VisualTreeHelper.GetChildrenCount(node); i++)
                Walk(Microsoft.UI.Xaml.Media.VisualTreeHelper.GetChild(node, i));
        }
        Walk(root);
        foreach (var image in images)
        {
            if (image.Source is not Microsoft.UI.Xaml.Media.Imaging.BitmapImage { UriSource: { Scheme: "http" or "https" } uri } bitmap
                || bitmap.PixelWidth > 0) continue;
            try
            {
                // En JPEG : Jellyfin envoie du WebP par défaut, sans décodeur sur certains Windows (Server).
                var url = uri.ToString().Replace("format=Webp", "format=Jpg", StringComparison.OrdinalIgnoreCase);
                var bytes = await Http.GetByteArrayAsync(url.Contains("format=") ? url : url + (uri.Query.Length > 0 ? "&" : "?") + "format=Jpg");
                using var stream = new Windows.Storage.Streams.InMemoryRandomAccessStream();
                await stream.WriteAsync(System.Runtime.InteropServices.WindowsRuntime.WindowsRuntimeBufferExtensions.AsBuffer(bytes));
                stream.Seek(0);
                var loaded = new Microsoft.UI.Xaml.Media.Imaging.BitmapImage { DecodePixelWidth = bitmap.DecodePixelWidth, DecodePixelType = bitmap.DecodePixelType };
                await loaded.SetSourceAsync(stream);
                image.Source = loaded;
            }
            catch (Exception e)
            {
                AppLog.Warn("capture", $"Image {uri.GetLeftPart(UriPartial.Path)} : {e.GetType().Name} 0x{e.HResult:X8} {e.Message}");
            }
        }
        if (images.Count > 0) await Task.Delay(500);
    }
}
