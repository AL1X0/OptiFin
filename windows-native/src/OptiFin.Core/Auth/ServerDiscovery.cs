using System.Net;
using System.Net.Sockets;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using OptiFin.Core.Api;

namespace OptiFin.Core.Auth;

/// <summary>
/// Découverte des serveurs Jellyfin du réseau local : datagramme UDP « who is JellyfinServer? »
/// en diffusion sur le port 7359 ; chaque serveur répond <c>{Address, Id, Name}</c>.
/// </summary>
public static class ServerDiscovery
{
    public const int Port = 7359;
    public const string Message = "who is JellyfinServer?";

    /// <summary>Liste cumulée (sans doublon) des serveurs trouvés pendant <paramref name="timeout"/>.</summary>
    public static async IAsyncEnumerable<IReadOnlyList<DiscoveredServer>> DiscoverAsync(
        TimeSpan? timeout = null, [EnumeratorCancellation] CancellationToken ct = default)
    {
        using var udp = new UdpClient(AddressFamily.InterNetwork) { EnableBroadcast = true };
        var sent = true;
        try
        {
            var payload = Encoding.UTF8.GetBytes(Message);
            await udp.SendAsync(payload, new IPEndPoint(IPAddress.Broadcast, Port), ct).ConfigureAwait(false);
        }
        catch (SocketException)
        {
            sent = false;
        }
        if (!sent)
        {
            yield return [];
            yield break;
        }

        var found = new Dictionary<string, DiscoveredServer>();
        using var limit = CancellationTokenSource.CreateLinkedTokenSource(ct);
        limit.CancelAfter(timeout ?? TimeSpan.FromSeconds(3));
        while (!limit.IsCancellationRequested)
        {
            UdpReceiveResult datagram;
            try
            {
                datagram = await udp.ReceiveAsync(limit.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (SocketException)
            {
                break;
            }
            var server = Parse(datagram.Buffer);
            if (server is null || found.ContainsKey(server.Id)) continue;
            found[server.Id] = server;
            yield return [.. found.Values];
        }
        if (found.Count == 0) yield return [];
    }

    /// <summary>Réponse de découverte → serveur ; null si invalide.</summary>
    public static DiscoveredServer? Parse(byte[] bytes)
    {
        try
        {
            var r = JsonSerializer.Deserialize(bytes, JellyfinJson.Default.DiscoveryResponse);
            if (r?.Id is not { Length: > 0 } id || r.Address is null) return null;
            var candidates = ServerAddress.Candidates(r.Address);
            if (candidates.Count == 0) return null;
            return new DiscoveredServer(id, string.IsNullOrEmpty(r.Name) ? candidates[0].Host : r.Name, candidates[0]);
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
