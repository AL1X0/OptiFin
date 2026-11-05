using System.Net;
using System.Net.Sockets;
using System.Security.Authentication;
using OptiFin.Core.Localization;

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
        ApiErrorKind.Unreachable => L.T("Serveur injoignable. Vérifiez l’adresse et votre connexion."),
        ApiErrorKind.Timeout => L.T("Le serveur met trop de temps à répondre."),
        ApiErrorKind.Certificate => L.T("Certificat HTTPS invalide pour ce serveur."),
        ApiErrorKind.Unauthorized => L.T("Identifiant ou mot de passe incorrect."),
        ApiErrorKind.Forbidden => L.T("Accès refusé par le serveur."),
        ApiErrorKind.Server => L.F("Erreur du serveur ({0}). Réessayez plus tard.", Status),
        ApiErrorKind.NotJellyfin => L.T("Cette adresse ne correspond pas à un serveur Jellyfin."),
        ApiErrorKind.UnsupportedVersion => L.F("Jellyfin {0} n’est pas pris en charge (10.9 minimum).", Detail),
        ApiErrorKind.QuickConnectDisabled => L.T("Quick Connect est désactivé sur ce serveur."),
        ApiErrorKind.PlaybackDenied => Detail switch
        {
            "NotAllowed" => L.T("La lecture de ce contenu n’est pas autorisée pour votre compte."),
            "NoCompatibleStream" => L.T("Aucun flux compatible : le serveur ne peut pas préparer ce fichier."),
            "RateLimitExceeded" => L.T("Limite de débit du serveur atteinte. Réessayez plus tard."),
            _ => L.F("Le serveur a refusé la lecture ({0}).", Detail),
        },
        _ => L.T("Une erreur inattendue est survenue."),
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
