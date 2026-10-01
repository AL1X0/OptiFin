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
        root.Loaded += async (_, _) =>
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
                    await Capture.SaveAsync(Player.PlayerLauncher.CurrentRoot ?? root, Path.Combine(folder, name + ".png"));
                }
                catch (Exception e)
                {
                    AppLog.Error("capture", $"Capture « {name} » impossible", e);
                }
            }
            window.Close();
        };
    }
}
