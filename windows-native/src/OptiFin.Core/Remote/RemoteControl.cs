using System.Text.Json;
using System.Text.Json.Nodes;
using OptiFin.Core.Api;

namespace OptiFin.Core.Remote;

/// <summary>Autre appareil connecté au même compte, pilotable, et ce qu'il est en train de lire.</summary>
public sealed record RemoteDevice(string SessionId, string Name, string? Client, string? NowPlayingId, string? NowPlaying, TimeSpan Position, TimeSpan? Runtime, bool Paused);

/// <summary>
/// « Lire sur… » : lancer et piloter la lecture d'un autre appareil par le serveur Jellyfin
/// (OptiFin, Jellyfin web et les autres clients qui acceptent d'être pilotés).
/// </summary>
public sealed class RemoteControlClient(JellyfinClient api, string userId)
{
    /// <summary>Annonce au serveur que cet appareil lit des vidéos et se laisse piloter.</summary>
    public static Task RegisterAsync(JellyfinClient api, CancellationToken ct = default) =>
        api.PostAsync("Sessions/Capabilities/Full", JellyfinClient.Json(new JsonObject
        {
            ["PlayableMediaTypes"] = new JsonArray("Video"),
            ["SupportedCommands"] = new JsonArray("Play", "Playstate"),
            ["SupportsMediaControl"] = true,
            ["SupportsPersistentIdentifier"] = true,
        }), ct: ct);

    public async Task<IReadOnlyList<RemoteDevice>> DevicesAsync(CancellationToken ct = default) =>
        Parse(await api.GetAsync("Sessions", JellyfinJson.Default.JsonElement,
            [new("controllableByUserId", userId), new("activeWithinSeconds", "960")], ct), api.Identity.DeviceId);

    public Task PlayAsync(string sessionId, string itemId, TimeSpan start, CancellationToken ct = default) =>
        api.PostAsync($"Sessions/{sessionId}/Playing", null,
            [new("playCommand", "PlayNow"), new("itemIds", itemId), new("startPositionTicks", start.Ticks.ToString())], ct);

    public Task PauseAsync(string sessionId, CancellationToken ct = default) => CommandAsync(sessionId, "Pause", null, ct);
    public Task UnpauseAsync(string sessionId, CancellationToken ct = default) => CommandAsync(sessionId, "Unpause", null, ct);
    public Task StopAsync(string sessionId, CancellationToken ct = default) => CommandAsync(sessionId, "Stop", null, ct);
    public Task SeekAsync(string sessionId, TimeSpan position, CancellationToken ct = default) => CommandAsync(sessionId, "Seek", position, ct);

    private Task CommandAsync(string sessionId, string command, TimeSpan? seek, CancellationToken ct) =>
        api.PostAsync($"Sessions/{sessionId}/Playing/{command}", null,
            seek is { } s ? [new("seekPositionTicks", s.Ticks.ToString())] : null, ct);

    /// <summary>Réponse du serveur → appareils pilotables capables de lire une vidéo, sauf celui-ci.</summary>
    public static IReadOnlyList<RemoteDevice> Parse(JsonElement sessions, string ownDeviceId)
    {
        if (sessions.ValueKind != JsonValueKind.Array) return [];
        var devices = new List<RemoteDevice>();
        foreach (var s in sessions.EnumerateArray())
        {
            if (Str(s, "Id") is not { } id || Str(s, "DeviceId") == ownDeviceId) continue;
            if (!s.TryGetProperty("SupportsRemoteControl", out var control) || control.ValueKind != JsonValueKind.True) continue;
            if (s.TryGetProperty("PlayableMediaTypes", out var types) && types.ValueKind == JsonValueKind.Array && types.GetArrayLength() > 0
                && !types.EnumerateArray().Any(t => t.GetString() == "Video")) continue;
            s.TryGetProperty("NowPlayingItem", out var playing);
            s.TryGetProperty("PlayState", out var state);
            devices.Add(new RemoteDevice(id, Str(s, "DeviceName") ?? Str(s, "Client") ?? id, Str(s, "Client"),
                Str(playing, "Id"), Str(playing, "Name"),
                TimeSpan.FromTicks(Long(state, "PositionTicks") ?? 0),
                Long(playing, "RunTimeTicks") is { } runtime ? TimeSpan.FromTicks(runtime) : null,
                state.ValueKind == JsonValueKind.Object && state.TryGetProperty("IsPaused", out var paused) && paused.ValueKind == JsonValueKind.True));
        }
        return devices;
    }

    private static string? Str(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    private static long? Long(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Number ? v.GetInt64() : null;
}
