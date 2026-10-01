using OptiFin.Core.Api;

namespace OptiFin.Core.Media;

/// <summary>
/// URL d'images redimensionnées par le serveur : largeur demandée = largeur affichée × échelle de
/// l'écran, arrondie au palier supérieur (meilleur taux de réussite du cache). Images publiques :
/// aucun jeton dans l'URL.
/// </summary>
public sealed class ImageUrls(Uri baseUrl)
{
    public static readonly int[] WidthBuckets = [120, 180, 240, 320, 480, 640, 800, 1080, 1280, 1920, 2560, 3840];

    public static int BucketFor(double logicalWidth, double scale)
    {
        var physical = (int)Math.Ceiling(logicalWidth * scale);
        foreach (var b in WidthBuckets)
            if (b >= physical) return b;
        return WidthBuckets[^1];
    }

    public Uri Image(ImageRef r, double logicalWidth, double scale = 1, int quality = 90, string format = "Webp")
    {
        var type = r.Type.ToString();
        var path = r.Type == ImageKind.Backdrop ? $"Items/{r.ItemId}/Images/{type}/{r.Index}" : $"Items/{r.ItemId}/Images/{type}";
        return Urls.Resolve(baseUrl, path,
        [
            new("maxWidth", BucketFor(logicalWidth, scale).ToString()),
            new("quality", quality.ToString()),
            new("format", format),
            new("tag", r.Tag),
        ]);
    }

    public Uri? Maybe(ImageRef? r, double logicalWidth, double scale = 1, int quality = 90) =>
        r is null ? null : Image(r, logicalWidth, scale, quality);

    public Uri UserAvatar(string userId, double logicalWidth, double scale = 1, string? tag = null) =>
        Urls.Resolve(baseUrl, $"Users/{userId}/Images/Primary",
        [
            new("maxWidth", BucketFor(logicalWidth, scale).ToString()),
            new("quality", "90"),
            new("format", "Webp"),
            new("tag", tag),
        ]);

    public Uri Chapter(string itemId, int index, string? tag, double logicalWidth, double scale = 1) =>
        Urls.Resolve(baseUrl, $"Items/{itemId}/Images/Chapter/{index}",
        [
            new("maxWidth", BucketFor(logicalWidth, scale).ToString()),
            new("quality", "85"),
            new("format", "Webp"),
            new("tag", tag),
        ]);
}
