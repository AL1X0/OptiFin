using System.Text.Json;

namespace OptiFin.Core.SyncPlay;

/// <summary>État d'une soirée (groupe SyncPlay) côté serveur.</summary>
public enum GroupState { Idle, Waiting, Paused, Playing }

/// <summary>Soirée : identifiant, nom, état, participants (noms d'utilisateur).</summary>
public sealed record GroupInfo(string Id, string Name, GroupState State, IReadOnlyList<string> Participants);

public enum SyncCommandKind { Unpause, Pause, Stop, Seek }

/// <summary>Ordre du serveur à appliquer à l'heure <see cref="When"/> (heure du serveur, UTC).</summary>
public sealed record SyncCommand(SyncCommandKind Kind, string PlaylistItemId, DateTime When, TimeSpan Position, DateTime EmittedAt);

public sealed record QueueItem(string ItemId, string PlaylistItemId);

/// <summary>File de lecture partagée : l'élément en cours et sa position de départ.</summary>
public sealed record PlayQueue(string Reason, IReadOnlyList<QueueItem> Items, int PlayingIndex, TimeSpan Start, bool IsPlaying, DateTime LastUpdate)
{
    public QueueItem? Current => PlayingIndex >= 0 && PlayingIndex < Items.Count ? Items[PlayingIndex] : null;
}

/// <summary>Message SyncPlay reçu par la connexion temps réel du serveur.</summary>
public abstract record SyncPlayMessage;
public sealed record GroupJoinedMessage(GroupInfo Group) : SyncPlayMessage;
public sealed record GroupLeftMessage(string GroupId) : SyncPlayMessage;
public sealed record UserJoinedMessage(string UserName) : SyncPlayMessage;
public sealed record UserLeftMessage(string UserName) : SyncPlayMessage;
public sealed record StateMessage(GroupState State, string Reason) : SyncPlayMessage;
public sealed record QueueMessage(PlayQueue Queue) : SyncPlayMessage;
public sealed record CommandMessage(SyncCommand Command) : SyncPlayMessage;
public sealed record ErrorMessage(string Kind, string UserMessage) : SyncPlayMessage;
public sealed record KeepAliveRequest(int Seconds) : SyncPlayMessage;

/// <summary>Lecture des messages de la connexion temps réel (/socket) : SyncPlay et maintien de la connexion.</summary>
public static class SyncPlayParser
{
    public static SyncPlayMessage? Parse(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            var type = Str(root, "MessageType");
            if (!root.TryGetProperty("Data", out var data)) return null;
            return type switch
            {
                "ForceKeepAlive" => new KeepAliveRequest(data.ValueKind == JsonValueKind.Number ? data.GetInt32() : 60),
                "SyncPlayCommand" => new CommandMessage(Command(data)),
                "SyncPlayGroupUpdate" => GroupUpdate(data),
                _ => null,
            };
        }
        catch (Exception e) when (e is JsonException or InvalidOperationException or FormatException or KeyNotFoundException)
        {
            return null;
        }
    }

    private static SyncPlayMessage? GroupUpdate(JsonElement update)
    {
        var type = Str(update, "Type");
        update.TryGetProperty("Data", out var data);
        return type switch
        {
            "GroupJoined" => new GroupJoinedMessage(Group(data)),
            "GroupLeft" => new GroupLeftMessage(data.ValueKind == JsonValueKind.String ? data.GetString()! : Str(update, "GroupId") ?? ""),
            "UserJoined" => new UserJoinedMessage(data.GetString() ?? ""),
            "UserLeft" => new UserLeftMessage(data.GetString() ?? ""),
            "StateUpdate" => new StateMessage(State(Str(data, "State")), Str(data, "Reason") ?? ""),
            "PlayQueue" => new QueueMessage(Queue(data)),
            "NotInGroup" => new ErrorMessage(type, "Vous ne faites plus partie de cette soirée."),
            "GroupDoesNotExist" => new ErrorMessage(type, "Cette soirée n’existe plus."),
            "CreateGroupDenied" => new ErrorMessage(type, "Votre compte n’a pas le droit de créer une soirée (réglage SyncPlay du serveur)."),
            "JoinGroupDenied" => new ErrorMessage(type, "Votre compte n’a pas le droit de rejoindre une soirée (réglage SyncPlay du serveur)."),
            "LibraryAccessDenied" => new ErrorMessage(type, "Un participant n’a pas accès à ce titre dans ses bibliothèques."),
            _ => null,
        };
    }

    public static GroupInfo Group(JsonElement e) => new(
        Str(e, "GroupId") ?? "",
        Str(e, "GroupName") ?? "Soirée",
        State(Str(e, "State")),
        e.TryGetProperty("Participants", out var p) && p.ValueKind == JsonValueKind.Array
            ? [.. p.EnumerateArray().Select(x => x.GetString() ?? "").Where(x => x.Length > 0)]
            : []);

    public static List<GroupInfo> Groups(JsonElement array) =>
        array.ValueKind == JsonValueKind.Array ? [.. array.EnumerateArray().Select(Group)] : [];

    public static SyncCommand Command(JsonElement e) => new(
        Enum.TryParse<SyncCommandKind>(Str(e, "Command"), out var kind) ? kind : SyncCommandKind.Stop,
        Str(e, "PlaylistItemId") ?? "",
        Time(e, "When"),
        TimeSpan.FromTicks(Long(e, "PositionTicks")),
        Time(e, "EmittedAt"));

    public static PlayQueue Queue(JsonElement e) => new(
        Str(e, "Reason") ?? "",
        e.TryGetProperty("Playlist", out var list) && list.ValueKind == JsonValueKind.Array
            ? [.. list.EnumerateArray().Select(i => new QueueItem(Str(i, "ItemId") ?? "", Str(i, "PlaylistItemId") ?? ""))]
            : [],
        e.TryGetProperty("PlayingItemIndex", out var index) && index.ValueKind == JsonValueKind.Number ? index.GetInt32() : -1,
        TimeSpan.FromTicks(Long(e, "StartPositionTicks")),
        e.TryGetProperty("IsPlaying", out var playing) && playing.ValueKind == JsonValueKind.True,
        Time(e, "LastUpdate"));

    private static GroupState State(string? s) => Enum.TryParse<GroupState>(s, out var state) ? state : GroupState.Idle;

    private static string? Str(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    private static long Long(JsonElement e, string name) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.Number ? v.GetInt64() : 0;

    private static DateTime Time(JsonElement e, string name) =>
        Str(e, name) is { } s && DateTime.TryParse(s, System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.AdjustToUniversal | System.Globalization.DateTimeStyles.AssumeUniversal, out var t)
            ? t
            : DateTime.UtcNow;
}
