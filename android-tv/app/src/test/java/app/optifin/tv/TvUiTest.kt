package app.optifin.tv

import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.test.core.app.ApplicationProvider
import app.optifin.tv.core.auth.TokenCipher
import app.optifin.tv.ui.shell.MainShell
import app.optifin.tv.ui.theme.OptiFinTheme
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Jetons en clair (Keystore absent des tests). */
private object PlainCipher : TokenCipher {
    override fun encrypt(plain: String) = plain
    override fun decrypt(cipher: String) = cipher
}

/**
 * Parcours de l'interface TV sur le serveur Jellyfin local (données réelles), télécommande
 * simulée, captures d'écran dans build/screens. Ignoré sans serveur de test
 * (OPTIFIN_TEST_JELLYFIN = fichier JSON {url, users:[{name,password}]} hors dépôt).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w960dp-h540dp-land-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TvUiTest {
    @get:Rule
    val compose = createComposeRule()

    private val screens = File("build/screens").apply { mkdirs() }

    @Before
    fun signIn() {
        val path = System.getenv("OPTIFIN_TEST_JELLYFIN")
        assumeTrue("Serveur Jellyfin de test absent", path != null && File(path).exists())
        val cfg = Json.parseToJsonElement(File(path!!).readText()).jsonObject
        val user = cfg["users"]!!.jsonArray[0].jsonObject
        AppServices.init(ApplicationProvider.getApplicationContext(), PlainCipher)
        runBlocking {
            val server = AppServices.auth.probe(cfg["url"]!!.jsonPrimitive.content)
            AppServices.signIn(AppServices.auth.login(server, user["name"]!!.jsonPrimitive.content, user["password"]!!.jsonPrimitive.content))
        }
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        val bitmap = compose.onRoot().captureToImage().asAndroidBitmap()
        File(screens, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private fun waitMs(ms: Long) {
        val end = System.currentTimeMillis() + ms
        while (System.currentTimeMillis() < end) {
            compose.mainClock.advanceTimeBy(100)
            Thread.sleep(50)
        }
    }

    @OptIn(ExperimentalTestApi::class)
    private fun press(key: Key, times: Int = 1) {
        repeat(times) {
            compose.onRoot().performKeyInput { pressKey(key) }
            waitMs(400)
        }
    }

    @Test
    fun `accueil, fiche et retour à la télécommande`() {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            OptiFinTheme { MainShell(MutableStateFlow(null), onPlay = { _, _ -> }, onAddAccount = {}) }
        }
        waitMs(6000)
        capture("01-accueil")
        press(Key.DirectionDown)
        capture("02-accueil-rangee")
        press(Key.DirectionDown)
        capture("03-accueil-rangee2")
        press(Key.DirectionUp, 3)
        capture("04-accueil-haut")
        press(Key.DirectionLeft)
        capture("05-menu")
        press(Key.DirectionRight)
        press(Key.DirectionDown)
        press(Key.DirectionCenter)
        waitMs(5000)
        capture("06-fiche")
        press(Key.DirectionDown, 2)
        capture("07-fiche-bas")
        press(Key.DirectionUp, 3)
        capture("08-fiche-haut")
    }
}
