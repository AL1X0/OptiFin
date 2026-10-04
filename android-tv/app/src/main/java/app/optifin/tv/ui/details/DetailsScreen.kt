package app.optifin.tv.ui.details

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.Movie
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusRestorer
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.tv.material3.Border
import androidx.tv.material3.Card
import androidx.tv.material3.CardDefaults
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.MediaFormat
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.core.media.PersonCredit
import app.optifin.tv.core.media.PersonKind
import app.optifin.tv.core.media.QualityBadges
import app.optifin.tv.core.media.StreamSummary
import app.optifin.tv.core.media.VideoRange
import app.optifin.tv.ui.components.AmbientBackdrop
import app.optifin.tv.ui.components.Avatar
import app.optifin.tv.ui.components.Badge
import app.optifin.tv.ui.components.CardStyle
import app.optifin.tv.ui.components.ItemActionsDialog
import app.optifin.tv.ui.components.MediaCard
import app.optifin.tv.ui.components.MediaRow
import app.optifin.tv.ui.components.ProgressLine
import app.optifin.tv.ui.components.Skeleton
import app.optifin.tv.ui.components.StatusMessage
import app.optifin.tv.ui.components.TitleLogo
import app.optifin.tv.ui.components.TvButton
import app.optifin.tv.ui.components.TvDialog
import app.optifin.tv.ui.components.TvIconButton
import app.optifin.tv.ui.home.open
import app.optifin.tv.ui.shell.AppNav
import app.optifin.tv.ui.theme.OF
import app.optifin.tv.ui.theme.PivotSpec
import coil3.compose.AsyncImage
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

private data class DetailsData(
    val item: MediaItem,
    val similar: List<MediaItem> = emptyList(),
    val seasons: List<MediaItem> = emptyList(),
    val nextUp: MediaItem? = null,
    val children: List<MediaItem> = emptyList(),
    val localTrailers: List<MediaItem> = emptyList(),
)

/**
 * Fiche : fond plein écran, logo, métadonnées et badges, synopsis, actions ; série : saisons et
 * épisodes ; distribution ; titres similaires ; informations techniques.
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
fun DetailsScreen(id: String, nav: AppNav) {
    var data by remember(id) { mutableStateOf<DetailsData?>(null) }
    var error by remember(id) { mutableStateOf<String?>(null) }
    var actions by remember { mutableStateOf<MediaItem?>(null) }
    var overview by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val images = AppServices.images

    suspend fun load() {
        val media = AppServices.media ?: return
        try {
            data = coroutineScope {
                val item = media.item(id)
                val similar = async { runCatching { media.similar(id) }.getOrDefault(emptyList()) }
                val seasons = async { if (item.kind == MediaKind.Series) runCatching { media.seasons(id) }.getOrDefault(emptyList()) else emptyList() }
                val nextUp = async { if (item.kind == MediaKind.Series) runCatching { media.nextUpFor(id) }.getOrNull() else null }
                val children = async {
                    if (item.kind == MediaKind.BoxSet || item.kind == MediaKind.Playlist) runCatching { media.children(id) }.getOrDefault(emptyList()) else emptyList()
                }
                val trailers = async { if (item.localTrailerCount > 0) runCatching { media.localTrailers(id) }.getOrDefault(emptyList()) else emptyList() }
                DetailsData(item, similar.await(), seasons.await(), nextUp.await(), children.await(), trailers.await())
            }
            error = null
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            // Rafraîchissement après une lecture en échec : la fiche reste affichée.
            if (data == null) error = e.userMessage()
        }
    }

    LifecycleResumeEffect(id) {
        val job = scope.launch { load() }
        onPauseOrDispose { job.cancel() }
    }
    LaunchedEffect(id) { AppServices.changes.collect { load() } }

    val current = data
    Box(Modifier.fillMaxSize()) {
        AmbientBackdrop(current?.item?.let { images?.maybe(it.backdrop, 1920) }, strength = 0.95f)
        when {
            current == null && error != null -> StatusMessage(error!!, action = "Réessayer", onAction = { scope.launch { load() } })
            current == null -> DetailsSkeleton()
            else -> {
                val pivot = remember { PivotSpec(0.12f) }
                val firstFocus = remember { FocusRequester() }
                val list = androidx.compose.foundation.lazy.rememberLazyListState()
                CompositionLocalProvider(LocalBringIntoViewSpec provides pivot) {
                    LazyColumn(
                        Modifier.fillMaxSize().focusRestorer(firstFocus),
                        state = list,
                        contentPadding = PaddingValues(bottom = 72.dp),
                        verticalArrangement = Arrangement.spacedBy(30.dp),
                    ) {
                        item(key = "header") {
                            // Retour sur les boutons de la fiche : la page remonte tout en haut.
                            Box(Modifier.onFocusChanged { if (it.hasFocus) scope.launch { list.animateScrollToItem(0) } }) {
                                Header(current, nav, firstFocus, onOverview = { overview = true })
                            }
                        }
                        if (current.seasons.isNotEmpty()) item(key = "seasons") { Seasons(current.item, current.seasons, current.nextUp, nav) { actions = it } }
                        if (current.children.isNotEmpty()) {
                            item(key = "children") {
                                MediaRow(if (current.item.kind == MediaKind.Playlist) "Contenu" else "Dans la collection", current.children, CardStyle.Poster,
                                    onClick = { nav.open(it) }, onLongClick = { actions = it })
                            }
                        }
                        val cast = current.item.people.filter { it.kind == PersonKind.Actor || it.kind == PersonKind.GuestStar }.take(40)
                        if (cast.isNotEmpty()) item(key = "cast") { CastRow(cast, nav) }
                        if (current.similar.isNotEmpty()) {
                            item(key = "similar") {
                                MediaRow("Titres similaires", current.similar, CardStyle.Poster, onClick = { nav.open(it) }, onLongClick = { actions = it })
                            }
                        }
                        if (current.item.streams.isNotEmpty()) item(key = "tech") { TechnicalInfo(current.item.streams) }
                    }
                }
                LaunchedEffect(current.item.id) { runCatching { firstFocus.requestFocus() } }
            }
        }
    }
    actions?.let { ItemActionsDialog(it, onDismiss = { actions = null }, onPlay = nav.play, onDetails = { d -> nav.details(d) }) }
    if (overview && current != null) {
        TvDialog(current.item.name, onDismiss = { overview = false }) {
            Text(current.item.overview ?: "", style = MaterialTheme.typography.bodyLarge, color = OF.TextPrimary)
            Spacer(Modifier.height(16.dp))
            TvButton("Fermer", { overview = false }, primary = true)
        }
    }
}

@Composable
private fun Header(data: DetailsData, nav: AppNav, firstFocus: FocusRequester, onOverview: () -> Unit) {
    val item = data.item
    val images = AppServices.images
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val height = (LocalConfiguration.current.screenHeightDp * 0.86f).dp
    var user by remember(item.id, item.user) { mutableStateOf(item.user) }

    fun toggle(played: Boolean? = null, favorite: Boolean? = null) {
        val media = AppServices.media ?: return
        scope.launch {
            try {
                user = when {
                    played != null -> media.setPlayed(item.id, played)
                    favorite != null -> media.setFavorite(item.id, favorite)
                    else -> user
                }
                AppServices.notifyChanged(item.id)
            } catch (e: Exception) {
                AppServices.notice(e.userMessage())
            }
        }
    }

    Column(
        Modifier.fillMaxWidth().heightIn(min = height).padding(start = OF.Gutter, end = OF.Gutter, top = OF.SafeY + 40.dp),
        verticalArrangement = Arrangement.Bottom,
    ) {
        Spacer(Modifier.weight(1f, fill = false).height(height * 0.25f))
        if (item.kind == MediaKind.Episode && item.seriesName != null) {
            Text(item.seriesName, style = MaterialTheme.typography.titleLarge, color = OF.TextSecondary)
            Spacer(Modifier.height(6.dp))
        }
        TitleLogo(if (item.kind != MediaKind.Episode) images?.maybe(item.logo, 800) else null, item.name, maxHeight = 170.dp)
        Spacer(Modifier.height(16.dp))
        val meta = listOfNotNull(item.episodeLabel) + MediaFormat.metadataLine(item)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            if (meta.isNotEmpty()) Text(meta.joinToString(" · "), style = MaterialTheme.typography.titleMedium, color = OF.TextSecondary)
            QualityBadges.forStreams(item.streams).forEach { Badge(it) }
        }
        if (item.genres.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Text(item.genres.joinToString(" · ") { it.name }, style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary)
        }
        item.overview?.let {
            Spacer(Modifier.height(14.dp))
            Surface(
                onClick = onOverview,
                modifier = Modifier.widthIn(max = 820.dp),
                shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(12.dp)),
                colors = ClickableSurfaceDefaults.colors(containerColor = Color.Transparent, focusedContainerColor = Color(0x26FFFFFF)),
                scale = ClickableSurfaceDefaults.scale(focusedScale = 1.01f),
            ) {
                Text(it, style = MaterialTheme.typography.bodyLarge, color = OF.TextPrimary, maxLines = 3, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp))
            }
        }
        Spacer(Modifier.height(22.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            when {
                item.kind.isPlayableVideo -> {
                    val resume = user.positionTicks > 0
                    TvButton(if (resume) "Reprendre" else "Lecture", { nav.play(item.id, false) }, Modifier.focusRequester(firstFocus),
                        icon = Icons.Rounded.PlayArrow, primary = true)
                    if (resume) TvIconButton(Icons.Rounded.Replay, "Lire depuis le début", { nav.play(item.id, true) })
                }
                item.kind == MediaKind.Series && data.nextUp != null -> {
                    val next = data.nextUp
                    val label = (if (next.user.positionTicks > 0) "Reprendre" else "Lecture") + (next.episodeLabel?.let { " $it" } ?: "")
                    TvButton(label, { nav.play(next.id, false) }, Modifier.focusRequester(firstFocus), icon = Icons.Rounded.PlayArrow, primary = true)
                }
                else -> Spacer(Modifier.size(0.dp).focusRequester(firstFocus))
            }
            if (item.kind != MediaKind.Person && item.kind != MediaKind.BoxSet) {
                TvIconButton(if (user.played) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked,
                    if (user.played) "Marquer comme non vu" else "Marquer comme vu", { toggle(played = !user.played) },
                    tint = if (user.played) OF.Accent else null)
            }
            TvIconButton(if (user.favorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
                if (user.favorite) "Retirer des favoris" else "Ajouter aux favoris", { toggle(favorite = !user.favorite) },
                tint = if (user.favorite) OF.Danger else null)
            val localTrailer = data.localTrailers.firstOrNull()
            val remoteTrailer = item.trailers.firstOrNull()
            if (localTrailer != null || remoteTrailer != null) {
                TvIconButton(Icons.Rounded.Movie, "Bande-annonce", {
                    if (localTrailer != null) nav.play(localTrailer.id, true)
                    else runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(remoteTrailer!!.url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                        .onFailure { AppServices.notice("Aucune appli ne peut lire cette bande-annonce.") }
                })
            }
            val seriesId = item.seriesId
            if (item.kind == MediaKind.Episode && seriesId != null) TvIconButton(Icons.Rounded.Tv, "Voir la série", { nav.details(seriesId) })
            if (item.kind.isPlayableVideo) {
                MediaFormat.remaining(item.copy(user = user))?.let { remaining ->
                    Column(Modifier.padding(start = 8.dp).width(160.dp)) {
                        user.progress?.let { ProgressLine(it) }
                        Spacer(Modifier.height(6.dp))
                        Text(remaining, style = MaterialTheme.typography.bodySmall, color = OF.TextSecondary)
                    }
                }
            }
        }
        Spacer(Modifier.height(24.dp))
    }
}

/** Saisons (onglets) et épisodes de la saison choisie (la saison en cours d'abord). */
@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
private fun Seasons(series: MediaItem, seasons: List<MediaItem>, nextUp: MediaItem?, nav: AppNav, onLongClick: (MediaItem) -> Unit) {
    val initial = seasons.indexOfFirst { it.id == nextUp?.seasonId }.takeIf { it >= 0 } ?: 0
    var selected by remember(series.id) { mutableStateOf(initial) }
    var episodes by remember(series.id) { mutableStateOf<List<MediaItem>?>(null) }
    val season = seasons.getOrNull(selected)
    LaunchedEffect(season?.id) {
        episodes = null
        val media = AppServices.media ?: return@LaunchedEffect
        episodes = season?.let { runCatching { media.episodes(series.id, it.id) }.getOrDefault(emptyList()) } ?: emptyList()
    }
    val gutterPx = with(LocalDensity.current) { OF.Gutter.toPx() }
    val rowSpec = remember { PivotSpec(0f, gutterPx) }
    Column {
        CompositionLocalProvider(LocalBringIntoViewSpec provides rowSpec) {
            LazyRow(Modifier.focusRestorer(), contentPadding = PaddingValues(horizontal = OF.Gutter), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                items(seasons.size) { i ->
                    val s = seasons[i]
                    Surface(
                        onClick = { selected = i },
                        shape = ClickableSurfaceDefaults.shape(RoundedCornerShape(24.dp)),
                        colors = ClickableSurfaceDefaults.colors(
                            containerColor = if (i == selected) Color(0x40FFFFFF) else Color(0x14FFFFFF),
                            contentColor = OF.TextPrimary, focusedContainerColor = Color.White, focusedContentColor = Color.Black,
                        ),
                    ) { Text(s.name, style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp)) }
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        val list = episodes
        if (list == null) {
            Row(Modifier.padding(start = OF.Gutter), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                repeat(4) { Skeleton(Modifier.width(CardStyle.Landscape.width).aspectRatio(16f / 9f)) }
            }
        } else {
            CompositionLocalProvider(LocalBringIntoViewSpec provides rowSpec) {
                LazyRow(Modifier.focusRestorer(), contentPadding = PaddingValues(horizontal = OF.Gutter, vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    items(list, key = { it.id }) { e -> EpisodeCard(e, onClick = { nav.play(e.id, false) }, onLongClick = { onLongClick(e) }) }
                }
            }
        }
    }
}

/** Carte d'épisode : vignette, numéro et titre, durée, synopsis court. */
@Composable
private fun EpisodeCard(episode: MediaItem, onClick: () -> Unit, onLongClick: () -> Unit) {
    Column(Modifier.width(CardStyle.Landscape.width)) {
        MediaCard(episode, CardStyle.Landscape, onClick = onClick, onLongClick = onLongClick, showTitle = false)
        Spacer(Modifier.height(10.dp))
        Text(listOfNotNull(episode.indexNumber?.let { "$it." }, episode.name).joinToString(" "),
            style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(listOfNotNull(MediaFormat.duration(episode.runtimeMs), MediaFormat.remaining(episode)).joinToString(" · "),
            style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary)
        episode.overview?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = OF.TextSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis) }
    }
}

/** Distribution : portraits ronds, nom et rôle ; OK ouvre la page de la personne. */
@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
private fun CastRow(cast: List<PersonCredit>, nav: AppNav) {
    val images = AppServices.images
    val gutterPx = with(LocalDensity.current) { OF.Gutter.toPx() }
    val rowSpec = remember { PivotSpec(0f, gutterPx) }
    Column {
        Text("Distribution", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(start = OF.Gutter, bottom = 14.dp))
        CompositionLocalProvider(LocalBringIntoViewSpec provides rowSpec) {
            LazyRow(Modifier.focusRestorer(), contentPadding = PaddingValues(horizontal = OF.Gutter, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(22.dp)) {
                items(cast, key = { it.id + it.role }) { p ->
                    Column(Modifier.width(120.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Card(
                            onClick = { nav.person(p.id) },
                            modifier = Modifier.size(112.dp),
                            shape = CardDefaults.shape(CircleShape),
                            scale = CardDefaults.scale(focusedScale = 1.1f),
                            border = CardDefaults.border(focusedBorder = Border(androidx.compose.foundation.BorderStroke(3.dp, Color.White), shape = CircleShape)),
                            colors = CardDefaults.colors(containerColor = OF.SurfaceRaised),
                        ) { Avatar(p.name, images?.maybe(p.image, 240), 112.dp) }
                        Spacer(Modifier.height(10.dp))
                        Text(p.name, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        p.role?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary, maxLines = 1, overflow = TextOverflow.Ellipsis) }
                    }
                }
            }
        }
    }
}

/** Informations techniques : vidéo (codec, définition, HDR), pistes audio. */
@Composable
private fun TechnicalInfo(streams: List<StreamSummary>) {
    Column(Modifier.padding(horizontal = OF.Gutter)) {
        Text("Informations techniques", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(12.dp))
        streams.filter { it.isVideo }.take(1).forEach { v ->
            val range = when (v.videoRange) {
                VideoRange.DolbyVision -> "Dolby Vision"
                VideoRange.Hdr10Plus -> "HDR10+"
                VideoRange.Hdr10 -> "HDR10"
                VideoRange.Hlg -> "HLG"
                VideoRange.Sdr -> "SDR"
            }
            InfoLine("Vidéo", listOfNotNull(v.codec.uppercase(), QualityBadges.resolutionLabel(v.width, v.height),
                if (v.width != null && v.height != null) "${v.width}×${v.height}" else null, v.bitDepth?.let { "$it bits" }, range).joinToString(" · "))
        }
        streams.filter { !it.isVideo }.take(6).forEachIndexed { i, a ->
            InfoLine(if (i == 0) "Audio" else "", a.title ?: listOfNotNull(QualityBadges.audioLabel(a) ?: a.codec.uppercase(), a.language).joinToString(" · "))
        }
    }
}

@Composable
private fun InfoLine(label: String, value: String) {
    Row(Modifier.padding(vertical = 3.dp)) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary, modifier = Modifier.width(120.dp))
        Text(value, style = MaterialTheme.typography.bodyMedium, color = OF.TextSecondary)
    }
}

@Composable
private fun DetailsSkeleton() {
    Column(Modifier.fillMaxSize().padding(start = OF.Gutter, top = 260.dp)) {
        Skeleton(Modifier.width(460.dp).height(110.dp))
        Spacer(Modifier.height(18.dp))
        Skeleton(Modifier.width(380.dp).height(20.dp), 6.dp)
        Spacer(Modifier.height(16.dp))
        Skeleton(Modifier.width(720.dp).height(18.dp), 6.dp)
        Spacer(Modifier.height(10.dp))
        Skeleton(Modifier.width(640.dp).height(18.dp), 6.dp)
        Spacer(Modifier.height(24.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Skeleton(Modifier.width(170.dp).height(50.dp), 25.dp)
            repeat(3) { Skeleton(Modifier.size(52.dp), 26.dp) }
        }
    }
}

/** Page d'une personne : portrait, biographie, filmographie. */
@Composable
fun PersonScreen(id: String, nav: AppNav) {
    var person by remember(id) { mutableStateOf<MediaItem?>(null) }
    var credits by remember(id) { mutableStateOf<List<MediaItem>>(emptyList()) }
    var error by remember(id) { mutableStateOf<String?>(null) }
    var actions by remember { mutableStateOf<MediaItem?>(null) }
    val images = AppServices.images
    val focus = remember { FocusRequester() }
    LaunchedEffect(id) {
        val media = AppServices.media ?: return@LaunchedEffect
        try {
            coroutineScope {
                val p = async { media.person(id) }
                val c = async { media.credits(id) }
                person = p.await()
                credits = c.await()
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            error = e.userMessage()
        }
    }
    val p = person
    Box(Modifier.fillMaxSize().background(OF.Background)) {
        when {
            p == null && error != null -> StatusMessage(error!!)
            p == null -> DetailsSkeleton()
            else -> LazyColumn(contentPadding = PaddingValues(top = OF.SafeY + 24.dp, bottom = 64.dp), verticalArrangement = Arrangement.spacedBy(32.dp)) {
                item {
                    Row(Modifier.padding(horizontal = OF.Gutter), horizontalArrangement = Arrangement.spacedBy(36.dp)) {
                        AsyncImage(images?.maybe(p.primary, 400), p.name, contentScale = ContentScale.Crop,
                            modifier = Modifier.width(220.dp).aspectRatio(2f / 3f).clip(RoundedCornerShape(16.dp)).background(OF.SurfaceRaised))
                        Column(Modifier.weight(1f)) {
                            Text(p.name, style = MaterialTheme.typography.displaySmall)
                            Spacer(Modifier.height(12.dp))
                            p.premiereDate?.let { Text("Né(e) le ${it.toLocalDate()}", style = MaterialTheme.typography.titleSmall, color = OF.TextSecondary) }
                            Spacer(Modifier.height(12.dp))
                            p.overview?.let { Text(it, style = MaterialTheme.typography.bodyLarge, color = OF.TextSecondary, maxLines = 9, overflow = TextOverflow.Ellipsis) }
                        }
                    }
                }
                if (credits.isNotEmpty()) item {
                    MediaRow("Filmographie", credits, CardStyle.Poster, onClick = { nav.open(it) }, onLongClick = { actions = it },
                        modifier = Modifier.focusRequester(focus))
                }
            }
        }
    }
    LaunchedEffect(credits.isNotEmpty()) { if (credits.isNotEmpty()) runCatching { focus.requestFocus() } }
    actions?.let { ItemActionsDialog(it, onDismiss = { actions = null }, onPlay = nav.play, onDetails = { d -> nav.details(d) }) }
}
