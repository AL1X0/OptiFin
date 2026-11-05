package app.optifin.tv.core.api

import app.optifin.tv.core.L
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLException
import kotlinx.coroutines.CancellationException

enum class ApiErrorKind {
    Unreachable, Timeout, Certificate, Unauthorized, Forbidden, Server, NotJellyfin, UnsupportedVersion,
    QuickConnectDisabled, PlaybackDenied, NotFound, Unexpected,
}

/** Erreur réseau ou API traduite en cas métier, avec un message clair (mêmes textes partout). */
class ApiException(
    val kind: ApiErrorKind,
    val detail: String? = null,
    val status: Int? = null,
) : Exception(detail ?: kind.name) {

    val userMessage: String
        get() = when (kind) {
            ApiErrorKind.Unreachable -> L.t("Serveur injoignable. Vérifiez l’adresse et votre connexion.")
            ApiErrorKind.Timeout -> L.t("Le serveur met trop de temps à répondre.")
            ApiErrorKind.Certificate -> L.t("Certificat HTTPS invalide pour ce serveur.")
            ApiErrorKind.Unauthorized -> L.t("Identifiant ou mot de passe incorrect.")
            ApiErrorKind.Forbidden -> L.t("Accès refusé par le serveur.")
            ApiErrorKind.Server -> L.f("Erreur du serveur ({0}). Réessayez plus tard.", status)
            ApiErrorKind.NotJellyfin -> L.t("Cette adresse ne correspond pas à un serveur Jellyfin.")
            ApiErrorKind.UnsupportedVersion -> L.f("Jellyfin {0} n’est pas pris en charge (10.9 minimum).", detail)
            ApiErrorKind.QuickConnectDisabled -> L.t("Quick Connect est désactivé sur ce serveur.")
            ApiErrorKind.NotFound -> L.t("Élément introuvable sur le serveur.")
            ApiErrorKind.PlaybackDenied -> when (detail) {
                "NotAllowed" -> L.t("La lecture de ce contenu n’est pas autorisée pour votre compte.")
                "NoCompatibleStream" -> L.t("Aucun flux compatible : le serveur ne peut pas préparer ce fichier.")
                "RateLimitExceeded" -> L.t("Limite de débit du serveur atteinte. Réessayez plus tard.")
                else -> L.f("Le serveur a refusé la lecture ({0}).", detail)
            }
            ApiErrorKind.Unexpected -> L.t("Une erreur inattendue est survenue.")
        }

    companion object {
        fun from(error: Throwable): ApiException = when (error) {
            is ApiException -> error
            is CancellationException -> throw error
            is SocketTimeoutException -> ApiException(ApiErrorKind.Timeout)
            is SSLException -> ApiException(ApiErrorKind.Certificate, error.message)
            is UnknownHostException, is ConnectException -> ApiException(ApiErrorKind.Unreachable, error.message)
            is IOException -> ApiException(ApiErrorKind.Unreachable, error.message)
            else -> ApiException(ApiErrorKind.Unexpected, error.message)
        }

        fun forStatus(status: Int): ApiException = when {
            status == 401 -> ApiException(ApiErrorKind.Unauthorized, status = 401)
            status == 403 -> ApiException(ApiErrorKind.Forbidden, status = 403)
            status == 404 -> ApiException(ApiErrorKind.NotFound, "HTTP 404", 404)
            status >= 500 -> ApiException(ApiErrorKind.Server, status = status)
            else -> ApiException(ApiErrorKind.Unexpected, "HTTP $status", status)
        }
    }
}

/** Erreur dont le message s'adresse directement à l'utilisateur. */
class UserFacingException(message: String) : Exception(message)

/** Message d'erreur à afficher, quelle que soit l'exception. */
fun Throwable.userMessage(): String = when (this) {
    is ApiException -> userMessage
    is UserFacingException -> message ?: ""
    else -> ApiException.from(this).userMessage
}
