package app.optifin.tv

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.navigation.compose.composable
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

    @Composable
    private fun Screen(content: @Composable (app.optifin.tv.ui.shell.AppNav) -> Unit) {
        val nav = androidx.navigation.compose.rememberNavController()
        val appNav = androidx.compose.runtime.remember { app.optifin.tv.ui.shell.AppNav(nav, { _, _ -> }, {}) }
        OptiFinTheme {
            androidx.compose.foundation.layout.Box(androidx.compose.ui.Modifier.fillMaxSize().background(app.optifin.tv.ui.theme.OF.Background)) {
                androidx.navigation.compose.NavHost(nav, startDestination = "x") { composable("x") { content(appNav) } }
            }
        }
    }

    private fun shot(name: String, wait: Long = 4000, content: @Composable (app.optifin.tv.ui.shell.AppNav) -> Unit) {
        compose.mainClock.autoAdvance = false
        compose.setContent { Screen(content) }
        waitMs(wait)
        capture(name)
    }

    @Test fun bibliotheques() = shot("10-bibliotheques") { app.optifin.tv.ui.library.LibrariesScreen(it) }

    @Test
    fun bibliothequeFilms() {
        val films = runBlocking { AppServices.media!!.userViews().first { v -> v.libraryType == app.optifin.tv.core.media.LibraryType.Movies } }
        shot("11-bibliotheque", 6000) { app.optifin.tv.ui.library.LibraryScreen(films.id, it) }
    }

    @Test fun recherche() = shot("12-recherche") { app.optifin.tv.ui.search.SearchScreen(it) }
    @Test fun reglages() = shot("13-reglages") { app.optifin.tv.ui.settings.SettingsScreen(it) }
    @Test fun compte() = shot("14-compte") { app.optifin.tv.ui.settings.AccountScreen(it) }
    @Test fun soiree() = shot("15-soiree", 6000) { app.optifin.tv.ui.party.PartyScreen(it) }
    @Test fun journaux() = shot("16-journaux") { app.optifin.tv.ui.settings.LogsScreen(it) }
}
