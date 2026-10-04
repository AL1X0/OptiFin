package app.optifin.tv.core.auth

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import app.optifin.tv.core.AppLog
import app.optifin.tv.core.api.JellyfinJson
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.serialization.Serializable

/** Chiffrement des jetons sur disque. */
interface TokenCipher {
    fun encrypt(plain: String): String
    fun decrypt(cipher: String): String?
}

/** Clé AES-GCM du Keystore Android : jamais exportable, jetons illisibles hors de l'appli. */
class KeystoreTokenCipher : TokenCipher {
    private val alias = "optifin-tokens"

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getEntry(alias, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    override fun encrypt(plain: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val data = cipher.doFinal(plain.toByteArray())
        return Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(data, Base64.NO_WRAP)
    }

    override fun decrypt(cipher: String): String? = try {
        val (iv, data) = cipher.split(':', limit = 2)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
        String(c.doFinal(Base64.decode(data, Base64.NO_WRAP)))
    } catch (e: Exception) {
        AppLog.w("auth", "Jeton illisible : ${e.message}")
        null
    }
}

@Serializable
data class StoredAccount(val server: JellyfinServer, val account: Account, val token: String? = null)

@Serializable
private data class AccountsFile(val active: String? = null, val accounts: List<StoredAccount> = emptyList())

/**
 * Comptes enregistrés (plusieurs serveurs et utilisateurs), compte actif, jetons chiffrés.
 * Fichier JSON dans le stockage privé de l'appli.
 */
class AccountStore(private val file: File, private val cipher: TokenCipher) {
    private var data: AccountsFile = read()

    private fun read(): AccountsFile = try {
        if (file.exists()) JellyfinJson.decodeFromString(AccountsFile.serializer(), file.readText()) else AccountsFile()
    } catch (e: Exception) {
        AppLog.w("auth", "Comptes illisibles : ${e.message}")
        AccountsFile()
    }

    private fun write() {
        file.parentFile?.mkdirs()
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(JellyfinJson.encodeToString(AccountsFile.serializer(), data))
        tmp.renameTo(file)
    }

    @Synchronized
    fun accounts(): List<StoredAccount> = data.accounts.map { it.copy(token = null) }

    val activeId: String? @Synchronized get() = data.active

    /** Session du compte actif (jeton déchiffré), null si aucun ou jeton perdu. */
    @Synchronized
    fun activeSession(): ActiveSession? = data.active?.let(::session)

    @Synchronized
    fun session(accountId: String): ActiveSession? {
        val stored = data.accounts.firstOrNull { it.account.id == accountId } ?: return null
        val token = stored.token?.let(cipher::decrypt) ?: return null
        return ActiveSession(stored.server, stored.account, token)
    }

    @Synchronized
    fun save(session: ActiveSession) {
        val stored = StoredAccount(session.server, session.account, cipher.encrypt(session.token))
        data = data.copy(
            active = session.account.id,
            accounts = listOf(stored) + data.accounts.filter { it.account.id != session.account.id },
        )
        write()
    }

    @Synchronized
    fun setActive(accountId: String?) {
        data = data.copy(active = accountId)
        write()
    }

    /** Déconnexion : le compte reste listé (reconnexion rapide), sans jeton. */
    @Synchronized
    fun forgetToken(accountId: String) {
        data = data.copy(
            active = if (data.active == accountId) null else data.active,
            accounts = data.accounts.map { if (it.account.id == accountId) it.copy(token = null) else it },
        )
        write()
    }

    @Synchronized
    fun remove(accountId: String) {
        data = data.copy(
            active = if (data.active == accountId) null else data.active,
            accounts = data.accounts.filter { it.account.id != accountId },
        )
        write()
    }
}
