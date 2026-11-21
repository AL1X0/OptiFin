using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization.Metadata;
using OptiFin.Core.Logging;

namespace OptiFin.Core.Api;

/// <summary>Identité du client envoyée dans l'en-tête <c>Authorization</c>.</summary>
public sealed record ClientIdentity(string ClientName, string DeviceName, string DeviceId, string Version)
{
    private readonly string _prefix = $"MediaBrowser Client={Q(ClientName)}, Device={Q(DeviceName)}, DeviceId={Q(DeviceId)}, Version={Q(Version)}";

    private static string Q(string v) => $"\"{Uri.EscapeDataString(v)}\"";

    /// <summary>
    /// <c>Authorization: MediaBrowser …</c> attendu par Jellyfin 10.9+. Valeurs encodées (le serveur
    /// les décode) : noms d'appareil avec guillemets, virgules ou accents acceptés.
    /// </summary>
    public string AuthorizationHeader(string? token) =>
        string.IsNullOrEmpty(token) ? _prefix : $"{_prefix}, Token={Q(token)}";
}

/// <summary>
/// Client HTTP Jellyfin minimal : JSON sans réflexion (compatible NativeAOT), en-tête
/// d'authentification à chaque requête (jamais de jeton dans l'URL), erreurs traduites en
/// <see cref="ApiException"/>.
/// </summary>
public sealed class JellyfinClient
{
    private static readonly HttpClient Shared = CreateHttp();
    private static readonly MediaTypeWithQualityHeaderValue AcceptJson = new("application/json");

    public static HttpClient SharedHttp => Shared;

    private static HttpClient CreateHttp()
    {
        var handler = new SocketsHttpHandler
        {
            PooledConnectionLifetime = TimeSpan.FromMinutes(5),
            AutomaticDecompression = System.Net.DecompressionMethods.All,
            ConnectTimeout = TimeSpan.FromSeconds(10),
            EnableMultipleHttp2Connections = true,
        };
        return new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(30) };
    }

    public JellyfinClient(Uri baseUrl, ClientIdentity identity, Func<string?>? token = null)
    {
        BaseUrl = baseUrl;
        Identity = identity;
        _token = token ?? (() => null);
    }

    private readonly Func<string?> _token;

    public Uri BaseUrl { get; }
    public ClientIdentity Identity { get; }

    /// <summary>Appelé sur un 401 alors qu'un jeton était envoyé (jeton révoqué côté serveur).</summary>
    public Action? OnUnauthorized { get; set; }

    public string AuthorizationHeader => Identity.AuthorizationHeader(_token());

    /// <summary>URL absolue d'un chemin serveur, en gardant un sous-chemin de proxy (https://h/jellyfin).</summary>
    public Uri Resolve(string path, IEnumerable<KeyValuePair<string, string?>>? query = null) =>
        Urls.Resolve(BaseUrl, path, query);

    public Task<T> GetAsync<T>(string path, JsonTypeInfo<T> type, IEnumerable<KeyValuePair<string, string?>>? query = null,
        CancellationToken ct = default) =>
        SendAsync(HttpMethod.Get, path, query, null, type, ct);

    public Task<T> PostAsync<T>(string path, HttpContent? body, JsonTypeInfo<T> type,
        IEnumerable<KeyValuePair<string, string?>>? query = null, CancellationToken ct = default) =>
        SendAsync(HttpMethod.Post, path, query, body, type, ct);

    public async Task PostAsync(string path, HttpContent? body = null, IEnumerable<KeyValuePair<string, string?>>? query = null,
        CancellationToken ct = default)
    {
        using var response = await SendRawAsync(HttpMethod.Post, path, query, body, ct).ConfigureAwait(false);
    }

    public Task<T> DeleteAsync<T>(string path, JsonTypeInfo<T> type, CancellationToken ct = default) =>
        SendAsync(HttpMethod.Delete, path, null, null, type, ct);

    public async Task DeleteAsync(string path, CancellationToken ct = default)
    {
        using var response = await SendRawAsync(HttpMethod.Delete, path, null, null, ct).ConfigureAwait(false);
    }

    public static async Task<byte[]> GetPublicBytesAsync(Uri url, TimeSpan? timeout = null, CancellationToken ct = default)
    {
        using var cts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        cts.CancelAfter(timeout ?? TimeSpan.FromSeconds(10));
        try
        {
            using var response = await Shared.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cts.Token).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadAsByteArrayAsync(cts.Token).ConfigureAwait(false);
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            throw ApiException.From(e);
        }
    }

    public async Task<byte[]> GetBytesAsync(string path, IEnumerable<KeyValuePair<string, string?>>? query = null, CancellationToken ct = default)
    {
        try
        {
            using var response = await SendRawAsync(HttpMethod.Get, path, query, null, ct, acceptJson: false).ConfigureAwait(false);
            return await response.Content.ReadAsByteArrayAsync(ct).ConfigureAwait(false);
        }
        catch (Exception e) when (e is not ApiException && (e is not OperationCanceledException || !ct.IsCancellationRequested))
        {
            throw ApiException.From(e);
        }
    }

    /// <summary>Réponse brute pour un long téléchargement, éventuellement à partir d'un octet (reprise).</summary>
    public Task<HttpResponseMessage> GetResponseAsync(string path, long from = 0, CancellationToken ct = default) =>
        SendRawAsync(HttpMethod.Get, path, null, null, ct, from, acceptJson: false);

    public static HttpContent Json<T>(T value, JsonTypeInfo<T> type) =>
        new ByteArrayContent(JsonSerializer.SerializeToUtf8Bytes(value, type))
        {
            Headers = { ContentType = new MediaTypeHeaderValue("application/json") { CharSet = "utf-8" } },
        };

    public static HttpContent Json(JsonObject value) =>
        new StringContent(value.ToJsonString(), Encoding.UTF8, "application/json");

    private async Task<T> SendAsync<T>(HttpMethod method, string path, IEnumerable<KeyValuePair<string, string?>>? query,
        HttpContent? body, JsonTypeInfo<T> type, CancellationToken ct)
    {
        using var response = await SendRawAsync(method, path, query, body, ct).ConfigureAwait(false);
        try
        {
            await using var stream = await response.Content.ReadAsStreamAsync(ct).ConfigureAwait(false);
            return await JsonSerializer.DeserializeAsync(stream, type, ct).ConfigureAwait(false)
                   ?? throw new ApiException(ApiErrorKind.Unexpected, "Réponse vide");
        }
        catch (JsonException e)
        {
            throw new ApiException(ApiErrorKind.Unexpected, $"Réponse illisible : {e.Message}");
        }
        catch (Exception e) when (e is not ApiException && (e is not OperationCanceledException || !ct.IsCancellationRequested))
        {
            throw ApiException.From(e);
        }
    }

    private async Task<HttpResponseMessage> SendRawAsync(HttpMethod method, string path,
        IEnumerable<KeyValuePair<string, string?>>? query, HttpContent? body, CancellationToken ct, long from = 0, bool acceptJson = true)
    {
        var url = Resolve(path, query);
        using var request = new HttpRequestMessage(method, url) { Content = body };
        if (from > 0) request.Headers.Range = new RangeHeaderValue(from, null);
        request.Headers.TryAddWithoutValidation("Authorization", AuthorizationHeader);
        if (acceptJson) request.Headers.Accept.Add(AcceptJson);
        HttpResponseMessage response;
        var started = Environment.TickCount64;
        try
        {
            response = await Shared.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct).ConfigureAwait(false);
        }
        catch (Exception e) when (e is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            AppLog.Warn("http", $"{method} {url.AbsolutePath} : {e.Message}");
            throw ApiException.From(e);
        }
        AppLog.Debug("http", $"{method} {url.AbsolutePath} → {(int)response.StatusCode} ({Environment.TickCount64 - started} ms)");
        if (response.IsSuccessStatusCode) return response;

        var status = (int)response.StatusCode;
        response.Dispose();
        if (status == 401 && !string.IsNullOrEmpty(_token())) OnUnauthorized?.Invoke();
        throw status switch
        {
            401 => new ApiException(ApiErrorKind.Unauthorized, status: 401),
            403 => new ApiException(ApiErrorKind.Forbidden, status: 403),
            >= 500 => new ApiException(ApiErrorKind.Server, status: status),
            _ => new ApiException(ApiErrorKind.Unexpected, $"HTTP {status}", status),
        };
    }
}

/// <summary>Construction d'URL serveur (pure, testée).</summary>
public static class Urls
{
    public static Uri Resolve(Uri baseUrl, string path, IEnumerable<KeyValuePair<string, string?>>? query = null)
    {
        var basePath = baseUrl.AbsolutePath.EndsWith('/') ? baseUrl.AbsolutePath : baseUrl.AbsolutePath + "/";
        var relative = path.StartsWith('/') ? path[1..] : path;
        var existingQuery = "";
        var q = relative.IndexOf('?');
        if (q >= 0)
        {
            existingQuery = relative[(q + 1)..];
            relative = relative[..q];
        }
        var parts = new List<string>();
        if (existingQuery.Length > 0) parts.Add(existingQuery);
        if (query != null)
        {
            foreach (var (key, value) in query)
            {
                if (value is null) continue;
                parts.Add($"{Uri.EscapeDataString(key)}={Uri.EscapeDataString(value)}");
            }
        }
        var builder = new UriBuilder(baseUrl) { Path = basePath + relative, Query = string.Join('&', parts) };
        return builder.Uri;
    }
}
