using OptiFin.App.Player;
using OptiFin.Core.Logging;

namespace OptiFin.App.Services;

/// <summary>
/// Une seule OptiFin à la fois : un nouveau lancement (double-clic répété pendant un démarrage lent,
/// raccourci…) ramène au premier plan la fenêtre déjà ouverte puis se ferme aussitôt.
/// </summary>
public static class SingleInstance
{
    private const string MutexName = @"Local\OptiFin.Windows.Instance";
    private const string SignalName = @"Local\OptiFin.Windows.Activate";

    private static Mutex? _mutex;
    private static EventWaitHandle? _signal;

    /// <summary>
    /// Vrai si ce processus est la première OptiFin. Sinon, la première est réveillée et ce
    /// processus doit quitter (avant d'ouvrir le journal ou une fenêtre).
    /// </summary>
    public static bool Claim()
    {
        _mutex = new Mutex(initiallyOwned: true, MutexName, out var first);
        _signal = new EventWaitHandle(false, EventResetMode.AutoReset, SignalName);
        if (first) return true;
        // Lancé par l'utilisateur, ce processus a le droit de passer au premier plan : il le cède à l'autre.
        Win32.AllowSetForegroundWindow(Win32.ASFW_ANY);
        _signal.Set();
        return false;
    }

    /// <summary>
    /// Écoute les lancements suivants et appelle <paramref name="activate"/> sur le fil d'interface.
    /// Un lancement survenu pendant le démarrage reste en attente et est servi dès l'appel.
    /// </summary>
    public static void Listen(Microsoft.UI.Dispatching.DispatcherQueue dispatcher, Action activate)
    {
        if (_signal is not { } signal) return;
        new Thread(() =>
        {
            while (signal.WaitOne())
            {
                AppLog.Info("app", "Nouveau lancement : la fenêtre déjà ouverte revient au premier plan");
                dispatcher.TryEnqueue(() => activate());
            }
        }) { IsBackground = true, Name = "Instance unique" }.Start();
    }

    /// <summary>Ramène une fenêtre au premier plan (restaurée si elle est réduite).</summary>
    public static void BringToFront(nint hwnd)
    {
        if (Win32.IsIconic(hwnd)) Win32.ShowWindow(hwnd, Win32.SW_RESTORE);
        Win32.SetForegroundWindow(hwnd);
    }
}
