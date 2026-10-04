package app.optifin.tv.ui.party

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.unit.dp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.WatchParty
import app.optifin.tv.core.syncplay.GroupInfo
import app.optifin.tv.core.syncplay.GroupState
import app.optifin.tv.ui.components.MenuRow
import app.optifin.tv.ui.shell.AppNav
import app.optifin.tv.ui.theme.OF
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Soirée : regarder ensemble, chacun chez soi (lecture, pause et avance synchronisées). Créer,
 * rejoindre, participants, quitter. Une fois dans la soirée, lancer un titre le lance pour tous.
 */
@Composable
fun PartyScreen(@Suppress("UNUSED_PARAMETER") nav: AppNav) {
    val group by WatchParty.group.collectAsState()
    val connected by WatchParty.connected.collectAsState()
    var groups by remember { mutableStateOf<List<GroupInfo>?>(null) }
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val first = remember { FocusRequester() }

    suspend fun refresh() {
        groups = runCatching { WatchParty.list() }.getOrDefault(emptyList())
    }
    LaunchedEffect(group, connected) {
        if (group == null) refresh()
    }
    LaunchedEffect(group == null) {
        delay(100)
        runCatching { first.requestFocus() }
    }

    fun run(action: suspend () -> Unit) {
        if (busy) return
        busy = true
        scope.launch {
            action()
            busy = false
        }
    }

    Column(Modifier.fillMaxSize().padding(top = OF.SafeY + 8.dp, start = OF.Gutter - 12.dp, end = OF.Gutter)) {
        Text("Soirée", style = MaterialTheme.typography.displaySmall, modifier = Modifier.padding(start = 12.dp))
        Text(
            "Regardez un film à plusieurs, chacun chez soi : lecture, pause et avance sont synchronisées.",
            style = MaterialTheme.typography.bodyLarge, color = OF.TextSecondary, modifier = Modifier.padding(start = 12.dp, top = 6.dp, bottom = 18.dp),
        )
        val g = group
        LazyColumn(Modifier.width(860.dp), contentPadding = PaddingValues(bottom = 48.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            if (g != null) {
                item {
                    Text(g.name, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(start = 12.dp))
                    Text(
                        when (g.state) {
                            GroupState.Playing -> "Lecture en cours"
                            GroupState.Paused -> "En pause"
                            GroupState.Waiting -> "En attente des participants…"
                            GroupState.Idle -> "Lancez un titre : il s’ouvrira chez tout le monde."
                        },
                        style = MaterialTheme.typography.bodyMedium, color = OF.TextSecondary, modifier = Modifier.padding(start = 12.dp, bottom = 12.dp),
                    )
                }
                item { Text("Participants", style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 6.dp)) }
                items(g.participants) { p ->
                    MenuRow(p, {}, if (p == g.participants.first()) Modifier.focusRequester(first) else Modifier, Icons.Rounded.Person,
                        supporting = if (p == AppServices.session.value?.account?.userName) "vous" else null)
                }
                item { Spacer(Modifier.height(12.dp)) }
                item { MenuRow("Quitter la soirée", { run { WatchParty.leave() } }, icon = Icons.AutoMirrored.Rounded.Logout) }
            } else {
                item {
                    val name = "Soirée de ${AppServices.session.value?.account?.userName ?: "OptiFin"}"
                    MenuRow("Créer une soirée", { run { WatchParty.create(name) } }, Modifier.focusRequester(first), Icons.Rounded.Add,
                        supporting = if (connected) name else "Connexion au serveur…")
                }
                item { Text("Soirées en cours", style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 16.dp)) }
                val list = groups
                if (list == null) item { Text("Recherche…", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary, modifier = Modifier.padding(12.dp)) }
                else if (list.isEmpty()) item { Text("Aucune soirée pour l’instant.", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary, modifier = Modifier.padding(12.dp)) }
                else items(list, key = { it.id }) { party ->
                    MenuRow(party.name, { run { WatchParty.join(party.id) } }, icon = Icons.Rounded.Groups,
                        supporting = "${party.participants.size} participant${if (party.participants.size > 1) "s" else ""} : ${party.participants.joinToString(", ")}")
                }
                item { MenuRow("Actualiser", { scope.launch { refresh() } }, icon = Icons.Rounded.Refresh) }
            }
        }
    }
}
