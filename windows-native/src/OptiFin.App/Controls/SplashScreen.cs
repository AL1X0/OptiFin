using System.Numerics;
using Microsoft.UI;
using Microsoft.UI.Composition;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Hosting;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Shapes;

namespace OptiFin.App.Controls;

/// <summary>
/// Écran de démarrage, affiché dès l'ouverture de la fenêtre pendant que services et accueil se
/// chargent : halo qui respire, logo qui apparaît avec un léger rebond, nom qui monte, trait de
/// chargement qui balaie. Animations du compositeur : fluides même quand le fil d'interface travaille.
/// </summary>
public sealed partial class SplashScreen : Grid
{
    private const float LogoSize = 84;
    private const float GlowSize = 340;
    private const float TrackWidth = 132;
    private const float SweepWidth = 44;

    private const int MinDisplayMs = 300;
    private const int FadeOutMs = 200;

    private readonly Compositor _compositor;
    private readonly Image _logo;
    private readonly TextBlock _name;
    private readonly Ellipse _glow;
    private readonly Border _track;
    private readonly Border _sweep;
    private readonly long _shownAt = Environment.TickCount64;
    private long _introEndsAt;
    private bool _introStarted;
    private bool _leaving;

    public SplashScreen()
    {
        Background = Ui.Res("OFBackgroundBrush");
        _compositor = ElementCompositionPreview.GetElementVisual(this).Compositor;
        var accent = (Windows.UI.Color)Application.Current.Resources["OFAccent"];

        _glow = new Ellipse
        {
            Width = GlowSize,
            Height = GlowSize,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 40),
            Fill = new RadialGradientBrush
            {
                GradientStops =
                {
                    new GradientStop { Color = Windows.UI.Color.FromArgb(0x70, accent.R, accent.G, accent.B), Offset = 0 },
                    new GradientStop { Color = Windows.UI.Color.FromArgb(0x22, accent.R, accent.G, accent.B), Offset = 0.45 },
                    new GradientStop { Color = Colors.Transparent, Offset = 1 },
                },
            },
        };

        _logo = new Image
        {
            Width = LogoSize,
            Height = LogoSize,
            Source = new BitmapImage(new Uri(System.IO.Path.Combine(AppContext.BaseDirectory, "Assets", "Logo.png"))),
        };
        _logo.ImageOpened += (_, _) => StartIntro();
        _logo.ImageFailed += (_, _) => StartIntro();

        _name = new TextBlock
        {
            Text = "OptiFin",
            FontSize = 26,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            CharacterSpacing = 40,
            Foreground = new SolidColorBrush(Colors.White),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 20, 0, 0),
        };

        _sweep = new Border
        {
            Width = SweepWidth,
            Height = 2,
            HorizontalAlignment = HorizontalAlignment.Left,
            CornerRadius = new CornerRadius(1),
            Background = new LinearGradientBrush
            {
                StartPoint = new Windows.Foundation.Point(0, 0),
                EndPoint = new Windows.Foundation.Point(1, 0),
                GradientStops =
                {
                    new GradientStop { Color = Colors.Transparent, Offset = 0 },
                    new GradientStop { Color = accent, Offset = 0.5 },
                    new GradientStop { Color = Colors.Transparent, Offset = 1 },
                },
            },
        };
        _track = new Border
        {
            Width = TrackWidth,
            Height = 2,
            Margin = new Thickness(0, 30, 0, 0),
            CornerRadius = new CornerRadius(1),
            Background = new SolidColorBrush(Windows.UI.Color.FromArgb(0x1F, 0xFF, 0xFF, 0xFF)),
            Child = _sweep,
        };

        var stack = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        stack.Children.Add(_logo);
        stack.Children.Add(_name);
        stack.Children.Add(_track);
        Children.Add(_glow);
        Children.Add(stack);

        foreach (var element in new UIElement[] { _logo, _name, _sweep, _glow })
            ElementCompositionPreview.SetIsTranslationEnabled(element, true);
        // Invisibles au départ (opacité du compositeur : celle de XAML reste à 1).
        foreach (var element in new UIElement[] { _logo, _name, _track, _glow })
            Visual(element).Opacity = 0;
        StartAmbient();
        // Logo lent à décoder : l'intro part quand même.
        Ui.After(TimeSpan.FromMilliseconds(250), StartIntro);
    }

    /// <summary>Halo qui respire et trait de chargement qui balaie, en boucle.</summary>
    private void StartAmbient()
    {
        var glow = Visual(_glow);
        glow.CenterPoint = new Vector3(GlowSize / 2, GlowSize / 2, 0);
        glow.StartAnimation("Opacity", Scalar(TimeSpan.FromMilliseconds(700), (0, 0), (1, 1)));
        var breathe = _compositor.CreateVector3KeyFrameAnimation();
        var smooth = _compositor.CreateCubicBezierEasingFunction(new Vector2(0.45f, 0), new Vector2(0.55f, 1));
        breathe.InsertKeyFrame(0, new Vector3(0.82f, 0.82f, 1));
        breathe.InsertKeyFrame(0.5f, new Vector3(1.08f, 1.08f, 1), smooth);
        breathe.InsertKeyFrame(1, new Vector3(0.82f, 0.82f, 1), smooth);
        breathe.Duration = TimeSpan.FromMilliseconds(2600);
        breathe.IterationBehavior = AnimationIterationBehavior.Forever;
        glow.StartAnimation("Scale", breathe);

        // Le trait ne sort pas de sa piste.
        Visual(_track).Clip = _compositor.CreateInsetClip();
        var sweep = _compositor.CreateVector3KeyFrameAnimation();
        sweep.InsertKeyFrame(0, new Vector3(-SweepWidth, 0, 0));
        sweep.InsertKeyFrame(1, new Vector3(TrackWidth, 0, 0), smooth);
        sweep.Duration = TimeSpan.FromMilliseconds(1100);
        sweep.IterationBehavior = AnimationIterationBehavior.Forever;
        Visual(_sweep).StartAnimation("Translation", sweep);
    }

    /// <summary>Logo (fondu + rebond), puis le nom qui monte, puis la piste de chargement.</summary>
    private void StartIntro() => StartIntro(fast: false);

    private void StartIntro(bool fast)
    {
        if (_introStarted) return;
        _introStarted = true;
        _introEndsAt = Environment.TickCount64 + (fast ? 240 : 850);
        var spring = _compositor.CreateCubicBezierEasingFunction(new Vector2(0.34f, 1.56f), new Vector2(0.64f, 1));
        var ease = _compositor.CreateCubicBezierEasingFunction(new Vector2(0.2f, 0), new Vector2(0, 1));

        if (fast)
            Visual(_glow).StartAnimation("Opacity", ScalarTo(TimeSpan.FromMilliseconds(220), 1, ease));

        var logo = Visual(_logo);
        logo.CenterPoint = new Vector3(LogoSize / 2, LogoSize / 2, 0);
        logo.StartAnimation("Opacity", Scalar(TimeSpan.FromMilliseconds(fast ? 140 : 420), (0, 0), (1, 1)));
        var pop = _compositor.CreateVector3KeyFrameAnimation();
        pop.InsertKeyFrame(0, new Vector3(0.6f, 0.6f, 1));
        pop.InsertKeyFrame(1, Vector3.One, spring);
        pop.Duration = TimeSpan.FromMilliseconds(fast ? 220 : 650);
        logo.StartAnimation("Scale", pop);

        var nameDelay = TimeSpan.FromMilliseconds(fast ? 50 : 180);
        var name = Visual(_name);
        var fade = Scalar(TimeSpan.FromMilliseconds(fast ? 160 : 450), (0, 0), (1, 1));
        fade.DelayTime = nameDelay;
        fade.DelayBehavior = AnimationDelayBehavior.SetInitialValueBeforeDelay;
        name.StartAnimation("Opacity", fade);
        var rise = _compositor.CreateVector3KeyFrameAnimation();
        rise.InsertKeyFrame(0, new Vector3(0, 14, 0));
        rise.InsertKeyFrame(1, Vector3.Zero, ease);
        rise.Duration = TimeSpan.FromMilliseconds(fast ? 200 : 550);
        rise.DelayTime = nameDelay;
        rise.DelayBehavior = AnimationDelayBehavior.SetInitialValueBeforeDelay;
        name.StartAnimation("Translation", rise);

        var track = Scalar(TimeSpan.FromMilliseconds(fast ? 140 : 400), (0, 0), (1, 1));
        track.DelayTime = TimeSpan.FromMilliseconds(fast ? 100 : 450);
        track.DelayBehavior = AnimationDelayBehavior.SetInitialValueBeforeDelay;
        Visual(_track).StartAnimation("Opacity", track);
    }

    /// <summary>Termine l'intro depuis son état courant sans repartir de zéro.</summary>
    private void ShortenIntro(TimeSpan duration)
    {
        var ease = _compositor.CreateCubicBezierEasingFunction(new Vector2(0.2f, 0), new Vector2(0, 1));
        Visual(_glow).StartAnimation("Opacity", ScalarTo(duration, 1, ease));
        Visual(_logo).StartAnimation("Opacity", ScalarTo(duration, 1, ease));
        Visual(_logo).StartAnimation("Scale", Vector3To(duration, Vector3.One, ease));
        Visual(_name).StartAnimation("Opacity", ScalarTo(duration, 1, ease));
        Visual(_name).StartAnimation("Translation", Vector3To(duration, Vector3.Zero, ease));
        Visual(_track).StartAnimation("Opacity", ScalarTo(duration, 1, ease));
    }

    /// <summary>
    /// Sortie : le logo s'approche, l'écran s'efface, puis il quitte l'arbre. Au moins ~300 ms pour
    /// éviter un clignotement ; si l'intro est encore en cours, on la raccourcit au lieu d'attendre.
    /// </summary>
    public void Dismiss()
    {
        if (_leaving) return;
        _leaving = true;
        var wait = Math.Max(1, MinDisplayMs - (Environment.TickCount64 - _shownAt));
        if (!_introStarted)
            StartIntro(fast: true);
        else if (Environment.TickCount64 < _introEndsAt)
            ShortenIntro(TimeSpan.FromMilliseconds(Math.Clamp(wait, 120, 200)));
        Ui.After(TimeSpan.FromMilliseconds(wait), Leave);
    }

    private void Leave()
    {
        IsHitTestVisible = false;
        var ease = _compositor.CreateCubicBezierEasingFunction(new Vector2(0.4f, 0), new Vector2(1, 1));
        Visual(_logo).StartAnimation("Scale", Vector3To(TimeSpan.FromMilliseconds(FadeOutMs), new Vector3(1.18f, 1.18f, 1), ease));
        Visual(this).StartAnimation("Opacity", Scalar(TimeSpan.FromMilliseconds(FadeOutMs), (0, 1), (1, 0)));
        Ui.After(TimeSpan.FromMilliseconds(FadeOutMs + 20), () =>
        {
            Visual(_glow).StopAnimation("Scale");
            Visual(_sweep).StopAnimation("Translation");
            (Parent as Panel)?.Children.Remove(this);
            OptiFin.Core.Logging.AppLog.Info("app", $"Écran de démarrage retiré après {Environment.TickCount64 - _shownAt} ms");
        });
    }

    private static Visual Visual(UIElement element) => ElementCompositionPreview.GetElementVisual(element);

    private ScalarKeyFrameAnimation Scalar(TimeSpan duration, (float at, float value) from, (float at, float value) to)
    {
        var animation = _compositor.CreateScalarKeyFrameAnimation();
        animation.InsertKeyFrame(from.at, from.value);
        animation.InsertKeyFrame(to.at, to.value);
        animation.Duration = duration;
        return animation;
    }

    private ScalarKeyFrameAnimation ScalarTo(TimeSpan duration, float to, CompositionEasingFunction? easing = null)
    {
        var animation = _compositor.CreateScalarKeyFrameAnimation();
        if (easing is null) animation.InsertKeyFrame(1, to);
        else animation.InsertKeyFrame(1, to, easing);
        animation.Duration = duration;
        return animation;
    }

    private Vector3KeyFrameAnimation Vector3To(TimeSpan duration, Vector3 to, CompositionEasingFunction easing)
    {
        var animation = _compositor.CreateVector3KeyFrameAnimation();
        animation.InsertKeyFrame(1, to, easing);
        animation.Duration = duration;
        return animation;
    }
}
