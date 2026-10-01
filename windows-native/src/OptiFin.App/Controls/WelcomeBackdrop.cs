using System.Numerics;
using Microsoft.UI.Composition;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Hosting;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Shapes;
using Windows.UI;

namespace OptiFin.App.Controls;

/// <summary>
/// Fond des écrans d'accueil (connexion) : grandes lueurs colorées qui dérivent lentement sur le noir,
/// façon aurore, puis un voile qui assombrit les bords. Tout est animé par le compositeur.
/// </summary>
public sealed partial class WelcomeBackdrop : Grid
{
    public WelcomeBackdrop()
    {
        IsHitTestVisible = false;
        SizeChanged += (_, e) => Clip = new RectangleGeometry { Rect = new Windows.Foundation.Rect(0, 0, e.NewSize.Width, e.NewSize.Height) };
        Background = new SolidColorBrush(Color.FromArgb(0xFF, 0, 0, 0));
        Add(Color.FromArgb(0x66, 0x4D, 0xA3, 0xFF), 900, HorizontalAlignment.Left, VerticalAlignment.Top, new Thickness(-260, -300, 0, 0), new Vector3(180, 120, 0), 19);
        Add(Color.FromArgb(0x55, 0x8B, 0x5C, 0xF6), 820, HorizontalAlignment.Right, VerticalAlignment.Bottom, new Thickness(0, 0, -240, -280), new Vector3(-160, -140, 0), 23);
        Add(Color.FromArgb(0x33, 0x2D, 0xD4, 0xBF), 640, HorizontalAlignment.Center, VerticalAlignment.Center, new Thickness(-420, 260, 0, 0), new Vector3(220, -160, 0), 29);
        // Vignette : bords plus sombres, centre lisible.
        Children.Add(new Border
        {
            Background = new RadialGradientBrush
            {
                Center = new Windows.Foundation.Point(0.5, 0.5),
                GradientOrigin = new Windows.Foundation.Point(0.5, 0.5),
                RadiusX = 0.75,
                RadiusY = 0.75,
                GradientStops =
                {
                    new GradientStop { Offset = 0, Color = Color.FromArgb(0x00, 0, 0, 0) },
                    new GradientStop { Offset = 1, Color = Color.FromArgb(0xB3, 0, 0, 0) },
                },
            },
        });
    }

    private void Add(Color color, double size, HorizontalAlignment h, VerticalAlignment v, Thickness margin, Vector3 drift, double seconds)
    {
        var blob = new Ellipse
        {
            Width = size,
            Height = size,
            HorizontalAlignment = h,
            VerticalAlignment = v,
            Margin = margin,
            Fill = new RadialGradientBrush
            {
                GradientStops =
                {
                    new GradientStop { Offset = 0, Color = color },
                    new GradientStop { Offset = 0.45, Color = Color.FromArgb((byte)(color.A / 2), color.R, color.G, color.B) },
                    new GradientStop { Offset = 1, Color = Color.FromArgb(0, color.R, color.G, color.B) },
                },
            },
        };
        Children.Add(blob);
        blob.Loaded += (_, _) =>
        {
            ElementCompositionPreview.SetIsTranslationEnabled(blob, true);
            var visual = ElementCompositionPreview.GetElementVisual(blob);
            var move = visual.Compositor.CreateVector3KeyFrameAnimation();
            move.InsertKeyFrame(0f, Vector3.Zero);
            move.InsertKeyFrame(0.33f, drift);
            move.InsertKeyFrame(0.66f, new Vector3(-drift.Y * 0.6f, drift.X * 0.5f, 0));
            move.InsertKeyFrame(1f, Vector3.Zero);
            move.Duration = TimeSpan.FromSeconds(seconds);
            move.IterationBehavior = AnimationIterationBehavior.Forever;
            visual.StartAnimation("Translation", move);
        };
    }
}

/// <summary>
/// Logo OptiFin des écrans d'accueil : apparition avec rebond, halo qui « respire » derrière.
/// </summary>
public sealed partial class WelcomeLogo : Grid
{
    public WelcomeLogo(double size = 96)
    {
        Width = size * 2;
        Height = size * 2;
        HorizontalAlignment = HorizontalAlignment.Center;
        var halo = new Ellipse
        {
            Width = size * 2,
            Height = size * 2,
            Fill = new RadialGradientBrush
            {
                GradientStops =
                {
                    new GradientStop { Offset = 0, Color = Color.FromArgb(0x80, 0x4D, 0xA3, 0xFF) },
                    new GradientStop { Offset = 0.5, Color = Color.FromArgb(0x26, 0x4D, 0xA3, 0xFF) },
                    new GradientStop { Offset = 1, Color = Color.FromArgb(0, 0x4D, 0xA3, 0xFF) },
                },
            },
        };
        var tile = new Border
        {
            Width = size,
            Height = size,
            CornerRadius = new CornerRadius(size * 0.28),
            BorderThickness = new Thickness(1),
            BorderBrush = new SolidColorBrush(Color.FromArgb(0x33, 0xFF, 0xFF, 0xFF)),
            Background = new LinearGradientBrush
            {
                StartPoint = new Windows.Foundation.Point(0, 0),
                EndPoint = new Windows.Foundation.Point(1, 1),
                GradientStops =
                {
                    new GradientStop { Offset = 0, Color = Color.FromArgb(0xFF, 0x2A, 0x2A, 0x30) },
                    new GradientStop { Offset = 1, Color = Color.FromArgb(0xFF, 0x08, 0x08, 0x0A) },
                },
            },
            Child = new Image
            {
                Width = size * 0.6,
                Height = size * 0.6,
                Source = new BitmapImage(new Uri(System.IO.Path.Combine(AppContext.BaseDirectory, "Assets", "Logo.png"))),
            },
        };
        Children.Add(halo);
        Children.Add(tile);
        Margin = new Thickness(0, -size / 2, 0, -size / 3);

        Loaded += (_, _) =>
        {
            var compositor = ElementCompositionPreview.GetElementVisual(this).Compositor;
            var spring = compositor.CreateCubicBezierEasingFunction(new Vector2(0.2f, 1.4f), new Vector2(0.4f, 1f));

            var tileVisual = ElementCompositionPreview.GetElementVisual(tile);
            tileVisual.CenterPoint = new Vector3((float)size / 2, (float)size / 2, 0);
            var pop = compositor.CreateVector3KeyFrameAnimation();
            pop.InsertKeyFrame(0f, new Vector3(0.6f, 0.6f, 1));
            pop.InsertKeyFrame(1f, Vector3.One, spring);
            pop.Duration = TimeSpan.FromMilliseconds(700);
            tileVisual.StartAnimation("Scale", pop);
            var fade = compositor.CreateScalarKeyFrameAnimation();
            fade.InsertKeyFrame(0f, 0f);
            fade.InsertKeyFrame(1f, 1f);
            fade.Duration = TimeSpan.FromMilliseconds(450);
            tileVisual.StartAnimation("Opacity", fade);

            var haloVisual = ElementCompositionPreview.GetElementVisual(halo);
            haloVisual.CenterPoint = new Vector3((float)size, (float)size, 0);
            var breathe = compositor.CreateVector3KeyFrameAnimation();
            breathe.InsertKeyFrame(0f, new Vector3(0.85f, 0.85f, 1));
            breathe.InsertKeyFrame(0.5f, new Vector3(1.08f, 1.08f, 1));
            breathe.InsertKeyFrame(1f, new Vector3(0.85f, 0.85f, 1));
            breathe.Duration = TimeSpan.FromSeconds(4.5);
            breathe.IterationBehavior = AnimationIterationBehavior.Forever;
            haloVisual.StartAnimation("Scale", breathe);
            var glow = compositor.CreateScalarKeyFrameAnimation();
            glow.InsertKeyFrame(0f, 0.55f);
            glow.InsertKeyFrame(0.5f, 1f);
            glow.InsertKeyFrame(1f, 0.55f);
            glow.Duration = TimeSpan.FromSeconds(4.5);
            glow.IterationBehavior = AnimationIterationBehavior.Forever;
            haloVisual.StartAnimation("Opacity", glow);
        };
    }
}
