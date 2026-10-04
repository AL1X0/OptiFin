package app.optifin.tv.core.api

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
            ApiErrorKind.Unreachable -> "Serveur injoignable. Vérifiez l’adresse et votre connexion."
            ApiErrorKind.Timeout -> "Le serveur met trop de temps à répondre."
            ApiErrorKind.Certificate -> "Certificat HTTPS invalide pour ce serveur."
            ApiErrorKind.Unauthorized -> "Identifiant ou mot de passe incorrect."
            ApiErrorKind.Forbidden -> "Accès refusé par le serveur."
            ApiErrorKind.Server -> "Erreur du serveur ($status). Réessayez plus tard."
            ApiErrorKind.NotJellyfin -> "Cette adresse ne correspond pas à un serveur Jellyfin."
            ApiErrorKind.UnsupportedVersion -> "Jellyfin $detail n’est pas pris en charge (10.9 minimum)."
            ApiErrorKind.QuickConnectDisabled -> "Quick Connect est désactivé sur ce serveur."
            ApiErrorKind.NotFound -> "Élément introuvable sur le serveur."
            ApiErrorKind.PlaybackDenied -> when (detail) {
                "NotAllowed" -> "La lecture de ce contenu n’est pas autorisée pour votre compte."
                "NoCompatibleStream" -> "Aucun flux compatible : le serveur ne peut pas préparer ce fichier."
                "RateLimitExceeded" -> "Limite de débit du serveur atteinte. Réessayez plus tard."
                else -> "Le serveur a refusé la lecture ($detail)."
            }
            ApiErrorKind.Unexpected -> "Une erreur inattendue est survenue."
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

/** Message d'erreur à afficher, quelle que soit l'exception. */
fun Throwable.userMessage(): String = (this as? ApiException)?.userMessage ?: ApiException.from(this).userMessage
