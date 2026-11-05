using System.Text.Json;
using System.Text.Json.Serialization;
using OptiFin.Core.Api;
using OptiFin.Core.Logging;
using OptiFin.Core.Media;
using OptiFin.Core.Playback;

namespace OptiFin.Core.Downloads;

public enum DownloadStatus { Queued, Running, Paused, Complete, Failed }

/// <summary>Film ou épisode téléchargé (ou en cours), avec sa fiche pour le lire sans serveur.</summary>
public sealed class DownloadRecord
{
    public string ItemId { get; set; } = "";
    public string AccountId { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Subtitle { get; set; }
    public string FileName { get; set; } = "";
    public string ItemJson { get; set; } = "";
    public long TotalBytes { get; set; }
    public long DoneBytes { get; set; }
    public DownloadStatus Status { get; set; }
    public string? Error { get; set; }
    /// <summary>Dernière position lue sur ce PC, et quand.</summary>
    public long? LocalPositionTicks { get; set; }
    public DateTimeOffset? LocalWatchedAt { get; set; }
    /// <summary>Position pas encore transmise au serveur (lecture sans connexion).</summary>
    public bool PositionUnsent { get; set; }
}

[JsonSourceGenerationOptions(WriteIndented = true, UseStringEnumConverter = true)]
[JsonSerializable(typeof(List<DownloadRecord>))]
internal sealed partial class DownloadJson : JsonSerializerContext;

/// <summary>
/// Téléchargements hors ligne : un fichier à la fois, reprise après pause ou coupure (Range), état
/// conservé d'un lancement à l'autre dans <c>downloads.json</c>. Fichier d'origine, sans transcodage.
/// </summary>
public sealed class DownloadManager
{
    private readonly string _directory;
    private readonly string _index;
    private readonly Lock _gate = new();
    private readonly List<DownloadRecord> _records;
    private JellyfinClient? _api;
    private string? _account;
    private string? _userId;
    private DownloadRecord? _running;
    private CancellationTokenSource? _cancel;
    private Task _worker = Task.CompletedTask;
    private int _syncing;
    /// <summary>Nouvel essai régulier : rien n'annonce le retour du serveur.</summary>
    private Timer? _syncTimer;

    /// <summary>État ou progression modifiés (appelé hors du fil d'interface).</summary>
    public event Action? Changed;

    public DownloadManager(string directory)
    {
        _directory = directory;
        _index = Path.Combine(directory, "downloads.json");
        _records = Load();
    }

    private List<DownloadRecord> Load()
    {
        try
        {
            if (!File.Exists(_index)) return [];
            var records = JsonSerializer.Deserialize(File.ReadAllText(_index), DownloadJson.Default.ListDownloadRecord) ?? [];
            // Interrompus par la fermeture de l'appli : ils repartent d'où ils en étaient.
            foreach (var r in records.Where(r => r.Status == DownloadStatus.Running)) r.Status = DownloadStatus.Queued;
            return records;
        }
        catch (Exception e)
        {
            AppLog.Warn("downloads", $"Liste des téléchargements illisible : {e.Message}");
            return [];
        }
    }

    private void Save()
    {
        try
        {
            Directory.CreateDirectory(_directory);
            var tmp = _index + ".tmp";
            lock (_gate)
            {
                File.WriteAllText(tmp, JsonSerializer.Serialize(_records, DownloadJson.Default.ListDownloadRecord));
                File.Move(tmp, _index, overwrite: true);
            }
        }
        catch (Exception e)
        {
            AppLog.Warn("downloads", $"Liste des téléchargements non enregistrée : {e.Message}");
        }
    }

    /// <summary>Compte actif : ses téléchargements en attente reprennent (null à la déconnexion).</summary>
    public void Attach(JellyfinClient? api, string? accountId, string? userId = null)
    {
        _cancel?.Cancel();
        lock (_gate)
        {
            _api = api;
            _account = accountId;
            _userId = userId;
        }
        Pump();
        if (api is null || userId is null) return;
        _syncTimer ??= new Timer(_ => _ = SyncPositionsAsync(), null, TimeSpan.FromMinutes(2), TimeSpan.FromMinutes(2));
        _ = SyncPositionsAsync();
    }

    // ------------------------------------------------------------ Position hors ligne

    /// <summary>Retient la position d'une lecture locale (le serveur peut être injoignable).</summary>
    public void SavePosition(string itemId, TimeSpan position)
    {
        lock (_gate)
        {
            if (_records.FirstOrDefault(r => r.ItemId == itemId && r.AccountId == _account) is not { } record) return;
            record.LocalPositionTicks = position.Ticks;
            record.LocalWatchedAt = DateTimeOffset.UtcNow;
            record.PositionUnsent = true;
        }
        Save();
    }

    /// <summary>
    /// Transmet au serveur les positions lues sans connexion. Une lecture plus récente sur un autre
    /// appareil l'emporte : elle remplace la position locale au lieu d'être écrasée.
    /// </summary>
    public async Task SyncPositionsAsync(CancellationToken ct = default)
    {
        if (Interlocked.Exchange(ref _syncing, 1) == 1) return;
        try
        {
            JellyfinClient? api;
            string? userId;
            List<DownloadRecord> unsent;
            lock (_gate)
            {
                api = _api;
                userId = _userId;
                unsent = [.. _records.Where(r => r.AccountId == _account && r.PositionUnsent)];
            }
            if (api is null || userId is null) return;
            foreach (var record in unsent)
            {
                var dto = (await api.GetAsync($"Users/{userId}/Items", JellyfinJson.Default.BaseItemDtoQueryResult,
                    [new("Ids", record.ItemId), new("EnableImages", "false"), new("EnableTotalRecordCount", "false")], ct).ConfigureAwait(false)).Items?.FirstOrDefault();
                var user = dto?.UserData;
                if (user?.LastPlayedDate > record.LocalWatchedAt)
                {
                    record.LocalPositionTicks = user.PlaybackPositionTicks ?? 0;
                    AppLog.Info("downloads", $"« {record.Name} » : position plus récente sur le serveur, gardée");
                }
                else if (dto != null && record.LocalPositionTicks is { } ticks)
                {
                    // Comme une fin de lecture : le serveur enregistre la position et marque « vu » près de la fin.
                    var report = new PlaybackReportDto { ItemId = record.ItemId, MediaSourceId = record.ItemId, PositionTicks = ticks };
                    await api.PostAsync("Sessions/Playing/Stopped", JellyfinClient.Json(report, JellyfinJson.Default.PlaybackReportDto), ct: ct).ConfigureAwait(false);
                    AppLog.Info("downloads", $"« {record.Name} » : position hors ligne envoyée au serveur");
                }
                record.PositionUnsent = false;
                Save();
            }
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            AppLog.Debug("downloads", $"Positions non envoyées, nouvel essai plus tard : {e.Message}");
        }
        finally
        {
            Volatile.Write(ref _syncing, 0);
        }
    }

    /// <summary>Épisode téléchargé qui suit <paramref name="episode"/> : pour enchaîner sans connexion.</summary>
    public MediaItem? NextDownloaded(MediaItem episode)
    {
        if (episode.SeriesId is null) return null;
        List<DownloadRecord> complete;
        lock (_gate) complete = [.. _records.Where(r => r.AccountId == _account && r.Status == DownloadStatus.Complete)];
        return complete.Select(ItemOf)
            .Where(i => i.SeriesId == episode.SeriesId && (i.ParentIndexNumber ?? 0, i.IndexNumber ?? 0).CompareTo((episode.ParentIndexNumber ?? 0, episode.IndexNumber ?? 0)) > 0)
            .OrderBy(i => i.ParentIndexNumber ?? 0).ThenBy(i => i.IndexNumber ?? 0)
            .FirstOrDefault();
    }

    /// <summary>Espace libre sur le disque des téléchargements (null si inconnu).</summary>
    public long? FreeBytes()
    {
        try
        {
            return new DriveInfo(Path.GetPathRoot(Path.GetFullPath(_directory))!).AvailableFreeSpace;
        }
        catch (Exception e) when (e is IOException or ArgumentException or UnauthorizedAccessException)
        {
            return null;
        }
    }

    public IReadOnlyList<DownloadRecord> Records()
    {
        lock (_gate) return [.. _records.Where(r => r.AccountId == _account)];
    }

    public DownloadRecord? Find(string itemId)
    {
        lock (_gate) return _records.FirstOrDefault(r => r.ItemId == itemId && r.AccountId == _account);
    }

    public string PathOf(DownloadRecord record) => Path.Combine(_directory, record.FileName);

    public string PosterPathOf(string itemId) => Path.Combine(_directory, itemId + ".jpg");

    /// <summary>Fichier d'un téléchargement terminé, pour le lire sans serveur.</summary>
    public string? CompletedFile(string itemId) =>
        Find(itemId) is { Status: DownloadStatus.Complete } r && File.Exists(PathOf(r)) ? PathOf(r) : null;

    /// <summary>Fiche enregistrée au téléchargement, avec la dernière position lue sur ce PC.</summary>
    public static MediaItem ItemOf(DownloadRecord record)
    {
        var item = MediaMapper.FromDto(JsonSerializer.Deserialize(record.ItemJson, JellyfinJson.Default.BaseItemDto)!);
        if (record.LocalPositionTicks is not { } ticks) return item;
        // Près de la fin, comme sur le serveur : titre vu, la prochaine lecture repart du début.
        var finished = item.RunTimeTicks is > 0 and var total && ticks >= total * 9 / 10;
        return item with { User = item.User with { PositionTicks = finished ? 0 : ticks, Played = item.User.Played || finished } };
    }

    public void Enqueue(BaseItemDto dto)
    {
        lock (_gate)
        {
            if (_account is null || _records.Any(r => r.ItemId == dto.Id && r.AccountId == _account)) return;
            var container = dto.MediaSources?.FirstOrDefault()?.Container?.Split(',')[0] ?? "mkv";
            var item = MediaMapper.FromDto(dto);
            _records.Add(new DownloadRecord
            {
                ItemId = dto.Id!,
                AccountId = _account,
                Name = item.Kind == MediaKind.Episode ? item.SeriesName ?? item.Name : item.Name,
                Subtitle = item.Kind == MediaKind.Episode ? $"{item.EpisodeLabel} · {item.Name}" : item.Year?.ToString(),
                FileName = $"{dto.Id}.{container}",
                ItemJson = JsonSerializer.Serialize(dto, JellyfinJson.Default.BaseItemDto),
                Status = DownloadStatus.Queued,
            });
        }
        Save();
        Changed?.Invoke();
        Pump();
    }

    public void Pause(string itemId)
    {
        DownloadRecord? record;
        lock (_gate)
        {
            record = _records.FirstOrDefault(r => r.ItemId == itemId && r.AccountId == _account);
            if (record is null) return;
            record.Status = DownloadStatus.Paused;
            if (_running == record) _cancel?.Cancel();
        }
        Save();
        Changed?.Invoke();
    }

    /// <summary>Reprend un téléchargement en pause ou en échec.</summary>
    public void Resume(string itemId)
    {
        lock (_gate)
        {
            if (_records.FirstOrDefault(r => r.ItemId == itemId && r.AccountId == _account) is not { } record) return;
            record.Status = DownloadStatus.Queued;
            record.Error = null;
        }
        Save();
        Changed?.Invoke();
        Pump();
    }

    public async Task DeleteAsync(string itemId)
    {
        DownloadRecord? record;
        Task worker;
        lock (_gate)
        {
            record = _records.FirstOrDefault(r => r.ItemId == itemId && r.AccountId == _account);
            if (record is null) return;
            _records.Remove(record);
            if (_running == record) _cancel?.Cancel();
            worker = _worker;
        }
        // Le fichier en cours d'écriture n'est libéré qu'une fois le téléchargement interrompu.
        if (_running == record) await worker.ConfigureAwait(false);
        foreach (var file in new[] { PathOf(record), PathOf(record) + ".part", PosterPathOf(itemId) })
        {
            try
            {
                File.Delete(file);
            }
            catch (Exception e)
            {
                AppLog.Warn("downloads", $"Fichier non supprimé : {e.Message}");
            }
        }
        Save();
        Changed?.Invoke();
        Pump();
    }

    /// <summary>Attend la fin de la file (tests).</summary>
    public Task IdleAsync() => _worker;

    private void Pump()
    {
        lock (_gate)
        {
            if (!_worker.IsCompleted) return;
            _worker = Task.Run(RunQueueAsync);
        }
    }

    private async Task RunQueueAsync()
    {
        while (true)
        {
            DownloadRecord? record;
            JellyfinClient? api;
            CancellationToken ct;
            lock (_gate)
            {
                api = _api;
                record = api is null ? null : _records.FirstOrDefault(r => r.AccountId == _account && r.Status == DownloadStatus.Queued);
                if (record is null)
                {
                    _running = null;
                    return;
                }
                _running = record;
                record.Status = DownloadStatus.Running;
                _cancel = new CancellationTokenSource();
                ct = _cancel.Token;
            }
            Save();
            Changed?.Invoke();
            await DownloadAsync(record, api!, ct).ConfigureAwait(false);
            lock (_gate) _running = null;
            Save();
            Changed?.Invoke();
        }
    }

    private async Task DownloadAsync(DownloadRecord record, JellyfinClient api, CancellationToken ct)
    {
        var part = PathOf(record) + ".part";
        try
        {
            Directory.CreateDirectory(_directory);
            var offset = File.Exists(part) ? new FileInfo(part).Length : 0;
            // Flux direct du fichier d'origine, comme sur mobile (/Items/{id}/Download dépend d'un droit à part).
            using var response = await api.GetResponseAsync($"Videos/{record.ItemId}/stream?static=true", offset, ct).ConfigureAwait(false);
            // Le serveur a ignoré la reprise : il renvoie tout depuis le début.
            if (response.StatusCode != System.Net.HttpStatusCode.PartialContent) offset = 0;
            var length = response.Content.Headers.ContentLength;
            if (length is { } l) record.TotalBytes = offset + l;
            record.DoneBytes = offset;
            await using var input = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
            await using (var output = new FileStream(part, offset > 0 ? FileMode.Append : FileMode.Create, FileAccess.Write, FileShare.Read))
            {
                var buffer = new byte[1 << 18];
                var lastNotice = Environment.TickCount64;
                while (true)
                {
                    // Connexion muette pendant une minute : échec (à reprendre), pas d'attente sans fin.
                    using var stall = CancellationTokenSource.CreateLinkedTokenSource(ct);
                    stall.CancelAfter(TimeSpan.FromMinutes(1));
                    var read = await input.ReadAsync(buffer, stall.Token).ConfigureAwait(false);
                    if (read == 0) break;
                    await output.WriteAsync(buffer.AsMemory(0, read), ct).ConfigureAwait(false);
                    record.DoneBytes += read;
                    if (Environment.TickCount64 - lastNotice < 500) continue;
                    lastNotice = Environment.TickCount64;
                    Changed?.Invoke();
                }
            }
            // Coupure silencieuse : une taille annoncée non atteinte n'est pas un fichier complet.
            if (length is not null && record.DoneBytes < record.TotalBytes) throw new IOException("Fichier incomplet");
            File.Move(part, PathOf(record), overwrite: true);
            record.TotalBytes = record.DoneBytes;
            record.Status = DownloadStatus.Complete;
            AppLog.Info("downloads", $"Téléchargé : {record.Name} ({record.DoneBytes / 1024 / 1024} Mo)");
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // Pause (état déjà posé), suppression ou déconnexion : reprendra au prochain lancement.
            if (record.Status == DownloadStatus.Running) record.Status = DownloadStatus.Queued;
        }
        catch (Exception e)
        {
            AppLog.Warn("downloads", $"Échec de « {record.Name} » : {e.Message}");
            record.Status = DownloadStatus.Failed;
            record.Error = e is ApiException api2 ? api2.UserMessage : e.Message;
        }
    }
}
