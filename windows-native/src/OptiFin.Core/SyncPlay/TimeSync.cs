namespace OptiFin.Core.SyncPlay;

/// <summary>
/// Horloge du serveur (comme NTP) : décalage estimé à partir de /GetUtcTime. On garde l'échantillon
/// au plus court aller-retour parmi les derniers, le plus fiable.
/// </summary>
public sealed class TimeSync(Func<DateTime>? utcNow = null)
{
    private readonly Func<DateTime> _now = utcNow ?? (() => DateTime.UtcNow);
    private readonly List<(TimeSpan Offset, TimeSpan Delay)> _samples = [];
    private readonly Lock _lock = new();

    /// <summary>Heure du serveur moins heure locale.</summary>
    public TimeSpan Offset { get; private set; }

    /// <summary>Aller-retour réseau du meilleur échantillon.</summary>
    public TimeSpan RoundTrip { get; private set; }

    public bool HasSamples => _samples.Count > 0;

    /// <summary>
    /// t0 : envoi (local), t1 : réception (serveur), t2 : réponse (serveur), t3 : réception (local).
    /// </summary>
    public void AddSample(DateTime t0, DateTime t1, DateTime t2, DateTime t3)
    {
        var offset = TimeSpan.FromTicks(((t1 - t0) + (t2 - t3)).Ticks / 2);
        var delay = (t3 - t0) - (t2 - t1);
        if (delay < TimeSpan.Zero) delay = TimeSpan.Zero;
        lock (_lock)
        {
            _samples.Add((offset, delay));
            if (_samples.Count > 8) _samples.RemoveAt(0);
            var best = _samples.MinBy(s => s.Delay);
            Offset = best.Offset;
            RoundTrip = best.Delay;
        }
    }

    public DateTime ServerNow => _now() + Offset;

    public DateTime LocalNow => _now();

    /// <summary>Heure locale correspondant à une heure du serveur.</summary>
    public DateTime ToLocal(DateTime server) => server - Offset;
}
