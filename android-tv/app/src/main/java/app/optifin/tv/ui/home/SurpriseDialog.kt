package app.optifin.tv.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccessTime
import androidx.compose.material.icons.rounded.Category
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.core.L
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.LibraryQuery
import app.optifin.tv.core.media.MediaFormat
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.core.media.NamedRef
import app.optifin.tv.ui.components.MenuRow
import app.optifin.tv.ui.components.TvDialog
import app.optifin.tv.ui.theme.OF
import coil3.compose.AsyncImage

/** « Surprends-moi » : un titre tiré au sort à l'ouverture, à refaire ou à filtrer par genre et durée. */
@Composable
fun SurpriseDialog(onDismiss: () -> Unit, onDetails: (String) -> Unit) {
    val media = AppServices.media ?: return
    val durations = remember { listOf(L.t("Peu importe la durée") to null, L.t("Moins de 1 h 30") to 90, L.t("Moins de 2 h") to 120) }
    var genres by remember { mutableStateOf<List<NamedRef>>(emptyList()) }
    var genre by remember { mutableStateOf<NamedRef?>(null) }
    var duration by remember { mutableIntStateOf(0) }
    var draw by remember { mutableIntStateOf(0) }
    var pick by remember { mutableStateOf<MediaItem?>(null) }
    var message by remember { mutableStateOf<String?>(null) }
    var choosingGenre by remember { mutableStateOf(false) }
    val first = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        runCatching { genres = media.filterOptions(LibraryQuery(kinds = listOf(MediaKind.Movie, MediaKind.Series))).genres }
    }
    LaunchedEffect(draw, genre, duration) {
        try {
            pick = media.surprise(genre?.id, durations[duration].second, pick?.id)
            message = if (pick == null) L.t("Aucun titre ne correspond.") else null
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            pick = null
            message = e.userMessage()
        }
    }
    LaunchedEffect(choosingGenre) { runCatching { first.requestFocus() } }

    TvDialog(L.t("Surprends-moi"), onDismiss) {
        if (choosingGenre) {
            LazyColumn(Modifier.heightIn(max = 420.dp)) {
                item {
                    MenuRow(L.t("Tous les genres"), { genre = null; choosingGenre = false }, Modifier.focusRequester(first), selected = genre == null)
                }
                items(genres, key = { it.id }) { g ->
                    MenuRow(g.name, { genre = g; choosingGenre = false }, selected = genre?.id == g.id)
                }
            }
            return@TvDialog
        }
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.heightIn(min = 150.dp)) {
            val current = pick
            if (current != null) {
                AsyncImage(AppServices.images?.maybe(current.poster, 180), null, contentScale = ContentScale.Crop, modifier = Modifier.width(100.dp).height(150.dp))
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(current.name, style = MaterialTheme.typography.titleLarge, color = OF.TextPrimary, maxLines = 2)
                    Text(MediaFormat.metadataLine(current).joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = OF.TextSecondary, maxLines = 1)
                    current.overview?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = OF.TextSecondary, maxLines = 4, overflow = TextOverflow.Ellipsis) }
                }
            } else {
                Text(message ?: L.t("Chargement…"), style = MaterialTheme.typography.bodyLarge, color = OF.TextSecondary, modifier = Modifier.padding(top = 8.dp))
            }
        }
        Spacer(Modifier.height(10.dp))
        MenuRow(L.t("Voir la fiche"), { pick?.let { onDismiss(); onDetails(it.id) } }, icon = Icons.Rounded.Info)
        MenuRow(L.t("Encore"), { draw++ }, Modifier.focusRequester(first), Icons.Rounded.Shuffle)
        MenuRow(genre?.name ?: L.t("Tous les genres"), { choosingGenre = true }, icon = Icons.Rounded.Category)
        MenuRow(durations[duration].first, { duration = (duration + 1) % durations.size }, icon = Icons.Rounded.AccessTime)
    }
}
