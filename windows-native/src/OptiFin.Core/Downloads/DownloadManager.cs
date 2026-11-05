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
    private DownloadRecord? _running;
    private CancellationTokenSource? _cancel;
    private Task _worker = Task.CompletedTask;

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
    public void Attach(JellyfinClient? api, string? accountId)
    {
        _cancel?.Cancel();
        lock (_gate)
        {
            _api = api;
            _account = accountId;
        }
        Pump();
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

    /// <summary>Fiche enregistrée au téléchargement.</summary>
    public static MediaItem ItemOf(DownloadRecord record) =>
        MediaMapper.FromDto(JsonSerializer.Deserialize(record.ItemJson, JellyfinJson.Default.BaseItemDto)!);

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
