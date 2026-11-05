package app.optifin.tv

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Serveur Jellyfin des tests de bout en bout : fichier JSON {url, users:[{name,password}]} désigné par
 * OPTIFIN_TEST_JELLYFIN (hors dépôt), sinon le serveur de démonstration public (un seul compte, sans
 * mot de passe). Les tests sont ignorés s'il est injoignable.
 */
object TestServer {
    data class User(val name: String, val password: String)

    private val config by lazy {
        val path = System.getenv("OPTIFIN_TEST_JELLYFIN")
        val text = if (path != null && File(path).exists()) File(path).readText()
        else """{"url":"https://demo.jellyfin.org/stable","users":[{"name":"demo","password":""}]}"""
        Json.parseToJsonElement(text).jsonObject
    }

    val url: String get() = config["url"]!!.jsonPrimitive.content

    /** Titre lu pendant le test des soirées ("testItem" du fichier, sinon le film de test du serveur local). */
    val testItem: String get() = config["testItem"]?.jsonPrimitive?.content ?: "fde8185a4a9b78e748dc26306f596e6a"

    val users: List<User>
        get() = config["users"]!!.jsonArray.map {
            User(it.jsonObject["name"]!!.jsonPrimitive.content, it.jsonObject["password"]!!.jsonPrimitive.content)
        }
}
