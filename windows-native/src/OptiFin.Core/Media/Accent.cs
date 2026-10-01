namespace OptiFin.Core.Media;

public readonly record struct Rgb(byte R, byte G, byte B);

/// <summary>
/// Couleur d'accent tirée d'une illustration (mêmes règles que sur mobile) : la teinte vive dominante
/// plutôt que la moyenne, souvent boueuse. Histogramme de teintes sur 24 secteurs pondéré par la
/// saturation, en ignorant les pixels trop sombres, trop clairs ou transparents.
/// </summary>
public static class Accent
{
    private const int Buckets = 24;

    /// <summary>Accent d'une image RGBA (pixels bruts, petite taille) ; null si l'image est quasi monochrome.</summary>
    public static Rgb? Dominant(ReadOnlySpan<byte> rgba)
    {
        Span<double> weight = stackalloc double[Buckets];
        Span<double> r = stackalloc double[Buckets];
        Span<double> g = stackalloc double[Buckets];
        Span<double> b = stackalloc double[Buckets];
        weight.Clear();
        r.Clear();
        g.Clear();
        b.Clear();

        for (var i = 0; i + 3 < rgba.Length; i += 4)
        {
            if (rgba[i + 3] < 128) continue;
            var (h, s, l) = ToHsl(rgba[i], rgba[i + 1], rgba[i + 2]);
            if (l < 0.12 || l > 0.9 || s < 0.2) continue;
            var bucket = (int)Math.Floor(h / 360 * Buckets) % Buckets;
            var w = s * (1 - Math.Abs(l - 0.5));
            weight[bucket] += w;
            r[bucket] += rgba[i] * w;
            g[bucket] += rgba[i + 1] * w;
            b[bucket] += rgba[i + 2] * w;
        }

        var best = 0;
        for (var i = 1; i < Buckets; i++)
            if (weight[i] > weight[best]) best = i;
        var pixels = rgba.Length / 4.0;
        // Moins de ~3 % de pixels colorés : image neutre.
        if (weight[best] <= 0 || weight[best] < pixels * 0.03 * 0.3) return null;
        var total = weight[best];
        return Normalize(new Rgb(
            (byte)Math.Round(r[best] / total), (byte)Math.Round(g[best] / total), (byte)Math.Round(b[best] / total)));
    }

    /// <summary>Accent lisible sur fond noir : luminosité 0,55–0,72, saturation 0,35–0,85.</summary>
    public static Rgb Normalize(Rgb source)
    {
        var (h, s, l) = ToHsl(source.R, source.G, source.B);
        return FromHsl(h, Math.Clamp(s, 0.35, 0.85), Math.Clamp(l, 0.55, 0.72));
    }

    public static (double H, double S, double L) ToHsl(byte red, byte green, byte blue)
    {
        double r = red / 255.0, g = green / 255.0, b = blue / 255.0;
        var max = Math.Max(r, Math.Max(g, b));
        var min = Math.Min(r, Math.Min(g, b));
        var delta = max - min;
        var l = (max + min) / 2;
        var s = delta == 0 ? 0 : delta / (1 - Math.Abs(2 * l - 1));
        double h;
        if (delta == 0) h = 0;
        else if (max == r) h = 60 * ((g - b) / delta % 6);
        else if (max == g) h = 60 * ((b - r) / delta + 2);
        else h = 60 * ((r - g) / delta + 4);
        if (h < 0) h += 360;
        return (h, s, l);
    }

    public static Rgb FromHsl(double h, double s, double l)
    {
        var c = (1 - Math.Abs(2 * l - 1)) * s;
        var x = c * (1 - Math.Abs(h / 60 % 2 - 1));
        var m = l - c / 2;
        var (r, g, b) = h switch
        {
            < 60 => (c, x, 0.0),
            < 120 => (x, c, 0.0),
            < 180 => (0.0, c, x),
            < 240 => (0.0, x, c),
            < 300 => (x, 0.0, c),
            _ => (c, 0.0, x),
        };
        static byte Channel(double v) => (byte)Math.Round(Math.Clamp(v, 0, 1) * 255);
        return new Rgb(Channel(r + m), Channel(g + m), Channel(b + m));
    }
}
