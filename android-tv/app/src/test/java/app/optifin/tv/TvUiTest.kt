package app.optifin.tv

import android.graphics.Bitmap
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.navigation.compose.composable
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isFocused
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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeNoException
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
 * Parcours de l'interface TV sur un vrai serveur Jellyfin (voir [TestServer]), télécommande
 * simulée : le focus est vérifié à chaque étape, captures d'écran dans build/screens (sans les
 * images, que ce banc de test ne charge pas).
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
        val user = TestServer.users[0]
        AppServices.init(ApplicationProvider.getApplicationContext(), PlainCipher)
        runBlocking {
            val server = try {
                AppServices.auth.probe(TestServer.url)
            } catch (e: Exception) {
                assumeNoException("Serveur Jellyfin de test injoignable", e)
                throw e
            }
            AppServices.signIn(AppServices.auth.login(server, user.name, user.password))
        }
    }

    private fun focused(text: String) = compose.onAllNodes(hasText(text) and isFocused(), useUnmergedTree = true)
        .fetchSemanticsNodes().isNotEmpty() || compose.onAllNodes(isFocused()).fetchSemanticsNodes()
        .any { node -> node.config.getOrNull(SemanticsProperties.Text)?.any { it.text == text } == true }

    private fun exists(text: String) = compose.onAllNodes(hasText(text), useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty()

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
        assertTrue("au démarrage, le focus est sur « Regarder »", focused("Regarder"))
        press(Key.DirectionDown)
        capture("02-accueil-rangee")
        assertFalse("▼ quitte le carrousel pour la première rangée", focused("Regarder"))
        press(Key.DirectionDown)
        capture("03-accueil-rangee2")
        press(Key.DirectionUp, 3)
        capture("04-accueil-haut")
        assertTrue("▲ ramène toujours en haut de page", focused("Regarder"))
        press(Key.DirectionLeft)
        capture("05-menu")
        assertTrue("◀ depuis le bord gauche ouvre le menu sur la page active", focused("Accueil"))
        press(Key.DirectionRight)
        assertTrue("▶ depuis le menu revient au contenu", focused("Regarder"))
        press(Key.DirectionDown)
        press(Key.DirectionCenter)
        waitMs(5000)
        capture("06-fiche")
        assertTrue("OK sur une carte ouvre sa fiche, focus sur la lecture", focused("Reprendre") || focused("Regarder") || focused("Lecture"))
        assertTrue("la fiche détaille le titre", exists("Distribution") || exists("Saisons") || exists("Épisodes"))
        press(Key.DirectionDown, 2)
        capture("07-fiche-bas")
        press(Key.DirectionUp, 3)
        capture("08-fiche-haut")
        assertTrue("▲ ramène en haut de la fiche", exists("Reprendre") || exists("Regarder") || exists("Lecture"))
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
