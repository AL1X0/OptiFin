package app.optifin.tv.ui.shell

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Groups
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.VideoLibrary
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.VideoLibrary
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.tv.material3.DrawerValue
import androidx.tv.material3.Icon
import androidx.tv.material3.NavigationDrawer
import androidx.tv.material3.NavigationDrawerItem
import androidx.tv.material3.NavigationDrawerItemDefaults
import androidx.tv.material3.NavigationDrawerScope
import androidx.tv.material3.Text
import androidx.tv.material3.rememberDrawerState
import app.optifin.tv.AppServices
import app.optifin.tv.R
import app.optifin.tv.ui.components.Avatar
import app.optifin.tv.ui.details.DetailsScreen
import app.optifin.tv.ui.details.PersonScreen
import app.optifin.tv.ui.home.HomeScreen
import app.optifin.tv.ui.library.LibrariesScreen
import app.optifin.tv.ui.library.LibraryScreen
import app.optifin.tv.ui.party.PartyScreen
import app.optifin.tv.ui.search.SearchScreen
import app.optifin.tv.ui.settings.AccountScreen
import app.optifin.tv.ui.settings.LogsScreen
import app.optifin.tv.ui.settings.SettingsScreen
import app.optifin.tv.ui.theme.OF
import kotlinx.coroutines.flow.MutableStateFlow
import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource

/** Navigation interne de l'appli (sous le menu latéral). */
object Screens {
    const val HOME = "home"
    const val SEARCH = "search"
    const val LIBRARIES = "libraries"
    const val LIBRARY = "library/{id}"
    const val DETAILS = "details/{id}"
    const val PERSON = "person/{id}"
    const val PARTY = "party"
    const val ACCOUNT = "account"
    const val SETTINGS = "settings"
    const val LOGS = "logs"
    fun library(id: String) = "library/$id"
    fun details(id: String) = "details/$id"
    fun person(id: String) = "person/$id"
}

/** Actions de navigation communes aux écrans. */
class AppNav(private val nav: NavHostController, val play: (String, Boolean) -> Unit, val addAccount: () -> Unit) {
    fun details(id: String) = nav.navigate(Screens.details(id))
    fun person(id: String) = nav.navigate(Screens.person(id))
    fun library(id: String) = nav.navigate(Screens.library(id))
    fun logs() = nav.navigate(Screens.LOGS)
    fun back() = nav.popBackStack()
    fun section(route: String) {
        nav.navigate(route) {
            popUpTo(Screens.HOME) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }
}

private data class DrawerEntry(val route: String, val label: String, val icon: ImageVector, val selectedIcon: ImageVector)

private val entries = listOf(
    DrawerEntry(Screens.SEARCH, "Recherche", Icons.Outlined.Search, Icons.Rounded.Search),
    DrawerEntry(Screens.HOME, "Accueil", Icons.Outlined.Home, Icons.Rounded.Home),
    DrawerEntry(Screens.LIBRARIES, "Bibliothèques", Icons.Outlined.VideoLibrary, Icons.Rounded.VideoLibrary),
    DrawerEntry(Screens.PARTY, "Soirée", Icons.Outlined.Groups, Icons.Rounded.Groups),
)

/**
 * Coquille : menu latéral TV (icônes, déployé avec libellés quand il a le focus, comme sur
 * Google TV) et pages. ◀ au bord gauche d'une page ouvre le menu ; Retour sur une page racine
 * ramène à l'accueil, puis quitte.
 */
@Composable
fun MainShell(launchItem: MutableStateFlow<String?>, onPlay: (String, Boolean) -> Unit, onAddAccount: () -> Unit) {
    val nav = rememberNavController()
    val appNav = remember(nav) { AppNav(nav, onPlay, onAddAccount) }
    val drawer = rememberDrawerState(DrawerValue.Closed)
    val backStack by nav.currentBackStackEntryAsState()
    val route = backStack?.destination?.route
    val session by AppServices.session.collectAsState()
    val pending by launchItem.collectAsState()

    LaunchedEffect(pending) {
        val id = pending ?: return@LaunchedEffect
        launchItem.value = null
        appNav.details(id)
    }

    // Page racine autre que l'accueil : Retour y ramène.
    BackHandler(enabled = route != Screens.HOME && nav.previousBackStackEntry == null) { appNav.section(Screens.HOME) }

    NavigationDrawer(
        modifier = Modifier.fillMaxSize().background(OF.Background),
        drawerState = drawer,
        drawerContent = { value ->
            DrawerContent(value, route, session?.account?.userName ?: "", appNav)
        },
    ) {
        Box(Modifier.fillMaxSize()) {
            NavHost(nav, startDestination = Screens.HOME) {
                composable(Screens.HOME) { HomeScreen(appNav) }
                composable(Screens.SEARCH) { SearchScreen(appNav) }
                composable(Screens.LIBRARIES) { LibrariesScreen(appNav) }
                composable(Screens.LIBRARY, listOf(navArgument("id") { type = NavType.StringType })) {
                    LibraryScreen(it.arguments!!.getString("id")!!, appNav)
                }
                composable(Screens.DETAILS, listOf(navArgument("id") { type = NavType.StringType })) {
                    DetailsScreen(it.arguments!!.getString("id")!!, appNav)
                }
                composable(Screens.PERSON, listOf(navArgument("id") { type = NavType.StringType })) {
                    PersonScreen(it.arguments!!.getString("id")!!, appNav)
                }
                composable(Screens.PARTY) { PartyScreen(appNav) }
                composable(Screens.ACCOUNT) { AccountScreen(appNav) }
                composable(Screens.SETTINGS) { SettingsScreen(appNav) }
                composable(Screens.LOGS) { LogsScreen(appNav) }
            }
        }
    }
}

@Composable
private fun NavigationDrawerScope.DrawerContent(value: DrawerValue, route: String?, userName: String, nav: AppNav) {
    val open = value == DrawerValue.Open
    val session = AppServices.session.value
    Box(
        Modifier.fillMaxHeight().background(
            if (open) Brush.horizontalGradient(listOf(Color(0xF7000000), Color(0xE6000000), Color(0x00000000)))
            else Brush.horizontalGradient(listOf(OF.Background, OF.Background.copy(alpha = 0.92f), Color(0x00000000))),
        ),
    ) {
        Column(
            Modifier.fillMaxHeight().padding(start = 12.dp, end = if (open) 60.dp else 22.dp, top = OF.SafeY, bottom = OF.SafeY),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Image(painterResource(R.drawable.logo_full), null, modifier = Modifier.padding(start = 6.dp).size(44.dp))
            Spacer(Modifier.weight(1f))
            for (entry in entries) {
                val selected = route == entry.route || (entry.route == Screens.LIBRARIES && route == Screens.LIBRARY)
                NavigationDrawerItem(
                    selected = selected,
                    onClick = { nav.section(entry.route) },
                    leadingContent = { Icon(if (selected) entry.selectedIcon else entry.icon, null) },
                    colors = drawerColors(),
                ) { Text(entry.label) }
            }
            NavigationDrawerItem(
                selected = route == Screens.ACCOUNT,
                onClick = { nav.section(Screens.ACCOUNT) },
                leadingContent = {
                    val images = AppServices.images
                    Avatar(userName, session?.let { images?.userAvatar(it.account.userId, 96, it.account.avatarTag) }, 28.dp)
                },
                colors = drawerColors(),
            ) { Text(userName.ifEmpty { "Compte" }) }
            NavigationDrawerItem(
                selected = route == Screens.SETTINGS || route == Screens.LOGS,
                onClick = { nav.section(Screens.SETTINGS) },
                leadingContent = { Icon(if (route == Screens.SETTINGS) Icons.Rounded.Settings else Icons.Outlined.Settings, null) },
                colors = drawerColors(),
            ) { Text("Réglages") }
            Spacer(Modifier.weight(1.4f))
        }
    }
}

@Composable
private fun drawerColors() = NavigationDrawerItemDefaults.colors(
    focusedContainerColor = Color.White,
    focusedContentColor = Color.Black,
    selectedContainerColor = Color(0x1FFFFFFF),
    selectedContentColor = OF.TextPrimary,
    contentColor = OF.TextSecondary,
)
