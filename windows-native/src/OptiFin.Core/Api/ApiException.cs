using System.Net;
using System.Net.Sockets;
using System.Security.Authentication;

namespace OptiFin.Core.Api;

public enum ApiErrorKind
{
    Unreachable,
    Timeout,
    Certificate,
    Unauthorized,
    Forbidden,
    Server,
    NotJellyfin,
    UnsupportedVersion,
    QuickConnectDisabled,
    PlaybackDenied,
    Unexpected,
}

/// <summary>
/// Erreur réseau ou API traduite en cas métier, avec un message clair pour l'utilisateur
/// (mêmes messages que sur iPhone et Android).
/// </summary>
public sealed class ApiException(ApiErrorKind kind, string? detail = null, int? status = null) : Exception(detail ?? kind.ToString())
{
    public ApiErrorKind Kind { get; } = kind;
    public int? Status { get; } = status;

    /// <summary>Détail technique (statut HTTP, début de réponse) : journaux et mode debug.</summary>
    public string? Detail { get; } = detail;

    public string UserMessage => Kind switch
    {
        ApiErrorKind.Unreachable => "Serveur injoignable. Vérifiez l’adresse et votre connexion.",
        ApiErrorKind.Timeout => "Le serveur met trop de temps à répondre.",
        ApiErrorKind.Certificate => "Certificat HTTPS invalide pour ce serveur.",
        ApiErrorKind.Unauthorized => "Identifiant ou mot de passe incorrect.",
        ApiErrorKind.Forbidden => "Accès refusé par le serveur.",
        ApiErrorKind.Server => $"Erreur du serveur ({Status}). Réessayez plus tard.",
        ApiErrorKind.NotJellyfin => "Cette adresse ne correspond pas à un serveur Jellyfin.",
        ApiErrorKind.UnsupportedVersion => $"Jellyfin {Detail} n’est pas pris en charge (10.9 minimum).",
        ApiErrorKind.QuickConnectDisabled => "Quick Connect est désactivé sur ce serveur.",
        ApiErrorKind.PlaybackDenied => Detail switch
        {
            "NotAllowed" => "La lecture de ce contenu n’est pas autorisée pour votre compte.",
            "NoCompatibleStream" => "Aucun flux compatible : le serveur ne peut pas préparer ce fichier.",
            "RateLimitExceeded" => "Limite de débit du serveur atteinte. Réessayez plus tard.",
            _ => $"Le serveur a refusé la lecture ({Detail}).",
        },
        _ => "Une erreur inattendue est survenue.",
    };

    public static ApiException From(Exception error) => error switch
    {
        ApiException api => api,
        TaskCanceledException or TimeoutException => new ApiException(ApiErrorKind.Timeout),
        HttpRequestException { InnerException: AuthenticationException } => new ApiException(ApiErrorKind.Certificate),
        HttpRequestException { StatusCode: HttpStatusCode.Unauthorized } => new ApiException(ApiErrorKind.Unauthorized, status: 401),
        HttpRequestException { StatusCode: HttpStatusCode.Forbidden } => new ApiException(ApiErrorKind.Forbidden, status: 403),
        HttpRequestException { StatusCode: { } code } when (int)code >= 500 => new ApiException(ApiErrorKind.Server, status: (int)code),
        HttpRequestException { StatusCode: { } code } => new ApiException(ApiErrorKind.Unexpected, $"HTTP {(int)code}", (int)code),
        HttpRequestException { InnerException: SocketException } or HttpRequestException => new ApiException(ApiErrorKind.Unreachable, error.Message),
        SocketException => new ApiException(ApiErrorKind.Unreachable, error.Message),
        _ => new ApiException(ApiErrorKind.Unexpected, error.Message),
    };
}
