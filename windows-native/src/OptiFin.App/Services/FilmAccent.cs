using System.Collections.Concurrent;
using System.Runtime.InteropServices.WindowsRuntime;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using Windows.Graphics.Imaging;
using Windows.Storage.Streams;
using Windows.UI;

namespace OptiFin.App.Services;

/// <summary>
/// Couleur propre à un film, tirée de son illustration (comme sur mobile) : fond ou affiche décodé
/// en 24 px, teinte vive dominante (<see cref="Accent"/>). Mémorisée par image pour la session.
/// </summary>
public static class FilmAccent
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(10) };
    private static readonly ConcurrentDictionary<string, Task<Color?>> Cache = new();

    /// <summary>Accent par défaut d'OptiFin.</summary>
    public static readonly Color Default = Color.FromArgb(0xFF, 0x4D, 0xA3, 0xFF);

    public static Task<Color?> ForAsync(MediaItem item)
    {
        if (AppServices.Images is not { } images || (item.Backdrop ?? item.Primary) is not { } image) return Task.FromResult<Color?>(null);
        // JPEG plutôt que WebP : décodable partout par Windows, et la plus petite taille servie suffit.
        var url = images.Image(image, 120, 1, 70, "Jpg");
        return Cache.GetOrAdd(url.ToString(), _ => ComputeAsync(url));
    }

    public static void Clear() => Cache.Clear();

    /// <summary>Accent déjà calculé (sans attendre), sinon null.</summary>
    public static Color? Cached(MediaItem item)
    {
        var task = ForAsync(item);
        return task.IsCompletedSuccessfully ? task.Result : null;
    }

    private static async Task<Color?> ComputeAsync(Uri url)
    {
        try
        {
            var bytes = await Http.GetByteArrayAsync(url).ConfigureAwait(false);
            using var stream = new InMemoryRandomAccessStream();
            await stream.WriteAsync(bytes.AsBuffer());
            stream.Seek(0);
            var decoder = await BitmapDecoder.CreateAsync(stream);
            var height = (uint)Math.Max(1, Math.Round(24.0 * decoder.PixelHeight / Math.Max(1, decoder.PixelWidth)));
            var pixels = await decoder.GetPixelDataAsync(BitmapPixelFormat.Rgba8, BitmapAlphaMode.Straight,
                new BitmapTransform { ScaledWidth = 24, ScaledHeight = height, InterpolationMode = BitmapInterpolationMode.Linear },
                ExifOrientationMode.IgnoreExifOrientation, ColorManagementMode.DoNotColorManage);
            return Accent.Dominant(pixels.DetachPixelData()) is { } rgb ? Color.FromArgb(0xFF, rgb.R, rgb.G, rgb.B) : null;
        }
        catch (Exception e)
        {
            AppLog.Debug("accent", $"Accent indisponible : {e.Message}");
            return null;
        }
    }

    public static Color WithAlpha(this Color c, byte alpha) => Color.FromArgb(alpha, c.R, c.G, c.B);
}
