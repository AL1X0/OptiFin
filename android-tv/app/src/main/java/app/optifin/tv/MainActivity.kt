package app.optifin.tv

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import app.optifin.tv.ui.NoticeHost
import app.optifin.tv.ui.auth.ConnectScreen
import app.optifin.tv.ui.auth.LoginScreen
import app.optifin.tv.ui.player.PlayerScreen
import app.optifin.tv.ui.shell.MainShell
import app.optifin.tv.ui.theme.OF
import app.optifin.tv.ui.theme.OptiFinTheme
import kotlinx.coroutines.flow.MutableStateFlow

/** Routes de premier niveau : connexion, appli (menu latéral), lecteur plein écran. */
object Routes {
    const val CONNECT = "connect"
    const val LOGIN = "login"
    const val MAIN = "main"
    const val PLAYER = "player/{id}?fromStart={fromStart}&party={party}"
    fun player(id: String, fromStart: Boolean = false, party: Boolean = false) = "player/$id?fromStart=$fromStart&party=$party"
}

class MainActivity : ComponentActivity() {
    /** Titre demandé par le lanceur (« Continuer à regarder ») : optifin://item/{id}. */
    private val launchItem = MutableStateFlow<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchItem.value = itemFrom(intent)
        setContent {
            OptiFinTheme {
                Box(Modifier.fillMaxSize().background(OF.Background)) {
                    AppNavigation(launchItem)
                    NoticeHost()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        itemFrom(intent)?.let { launchItem.value = it }
    }

    private fun itemFrom(intent: Intent?): String? =
        intent?.data?.takeIf { it.scheme == "optifin" && it.host == "item" }?.lastPathSegment
}

@Composable
private fun AppNavigation(launchItem: MutableStateFlow<String?>) {
    val nav = rememberNavController()
    val session by AppServices.session.collectAsState()
    val start = if (AppServices.session.value != null) Routes.MAIN else Routes.CONNECT

    // Session perdue (déconnexion, jeton révoqué) : retour à la connexion.
    LaunchedEffect(session) {
        if (session == null && nav.currentDestination?.route != Routes.CONNECT && nav.currentDestination?.route != Routes.LOGIN) {
            nav.navigate(Routes.CONNECT) { popUpTo(0) }
        }
    }

    NavHost(nav, startDestination = start) {
        composable(Routes.CONNECT) {
            ConnectScreen(onServer = { nav.navigate(Routes.LOGIN) }, onSignedIn = { goMain(nav) })
        }
        composable(Routes.LOGIN) {
            LoginScreen(onSignedIn = { goMain(nav) }, onBack = { nav.popBackStack() })
        }
        composable(Routes.MAIN) {
            MainShell(
                launchItem = launchItem,
                onPlay = { id, fromStart -> nav.navigate(Routes.player(id, fromStart)) },
                onAddAccount = { nav.navigate(Routes.CONNECT) },
            )
        }
        composable(
            Routes.PLAYER,
            arguments = listOf(
                navArgument("id") { type = NavType.StringType },
                navArgument("fromStart") { type = NavType.BoolType; defaultValue = false },
                navArgument("party") { type = NavType.BoolType; defaultValue = false },
            ),
        ) { entry ->
            val args = entry.arguments!!
            PlayerScreen(
                itemId = args.getString("id")!!,
                fromStart = args.getBoolean("fromStart"),
                onExit = { nav.popBackStack() },
                onPlayItem = { next -> nav.navigate(Routes.player(next)) { popUpTo(Routes.PLAYER) { inclusive = true } } },
            )
        }
    }
}

private fun goMain(nav: NavHostController) {
    nav.navigate(Routes.MAIN) { popUpTo(0) }
}
