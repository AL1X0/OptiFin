package app.optifin.tv.ui.home

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.PlayArrow
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusRestorer
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.tv.material3.Carousel
import androidx.tv.material3.CarouselDefaults
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import androidx.tv.material3.rememberCarouselState
import app.optifin.tv.AppServices
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.HomeData
import app.optifin.tv.core.media.MediaFormat
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.ui.components.AmbientBackdrop
import app.optifin.tv.ui.components.CardStyle
import app.optifin.tv.ui.components.ItemActionsDialog
import app.optifin.tv.ui.components.MediaRow
import app.optifin.tv.ui.components.Skeleton
import app.optifin.tv.ui.components.SkeletonRow
import app.optifin.tv.ui.components.StatusMessage
import app.optifin.tv.ui.components.TvButton
import app.optifin.tv.ui.shell.AppNav
import app.optifin.tv.ui.theme.OF
import app.optifin.tv.ui.theme.PivotSpec
import coil3.compose.AsyncImage
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** Ouvre un élément : fiche, page de personne ou bibliothèque. */
fun AppNav.open(item: MediaItem) = when (item.kind) {
    MediaKind.Person -> person(item.id)
    MediaKind.CollectionFolder, MediaKind.Folder -> library(item.id)
    MediaKind.Season -> details(item.seriesId ?: item.id)
    else -> details(item.id)
}

/** Lecture depuis une carte : film / épisode directement, série → fiche. */
fun AppNav.playOrOpen(item: MediaItem) = if (item.kind.isPlayableVideo) play(item.id, false) else open(item)

/**
 * Accueil : carrousel « À la une » plein écran puis rangées. Le fond d'ambiance suit l'élément
 * focalisé ; la page défile en « pivot » (élément focalisé toujours au même endroit).
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
fun HomeScreen(nav: AppNav) {
    var data by remember { mutableStateOf<HomeData?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var backdrop by remember { mutableStateOf<String?>(null) }
    var actions by remember { mutableStateOf<MediaItem?>(null) }
    val scope = rememberCoroutineScope()
    var job by remember { mutableStateOf<Job?>(null) }
    val images = AppServices.images

    fun load() {
        job?.cancel()
        job = scope.launch {
            try {
                AppServices.home?.watch()?.collect {
                    data = it
                    error = null
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                if (data == null) error = e.userMessage()
            }
        }
    }

    // Retour sur l'accueil (fin de lecture, fiche) : progression et « Reprendre » à jour.
    LifecycleResumeEffect(Unit) {
        load()
        onPauseOrDispose { }
    }
    LaunchedEffect(Unit) { AppServices.changes.collect { load() } }

    Box(Modifier.fillMaxSize()) {
        AmbientBackdrop(backdrop)
        val current = data
        when {
            current == null && error != null -> StatusMessage(error!!, action = "Réessayer", onAction = ::load)
            current == null -> HomeSkeleton()
            current.isEmpty -> StatusMessage("Votre serveur ne contient encore rien à afficher.")
            else -> {
                val pivot = remember { PivotSpec(0.22f) }
                val firstFocus = remember { FocusRequester() }
                CompositionLocalProvider(LocalBringIntoViewSpec provides pivot) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize().focusRestorer(firstFocus),
                        contentPadding = PaddingValues(bottom = 80.dp),
                        verticalArrangement = Arrangement.spacedBy(28.dp),
                    ) {
                        if (current.featured.isNotEmpty()) {
                            item(key = "featured") {
                                Featured(current.featured, nav, Modifier.focusRequester(firstFocus)) { item ->
                                    backdrop = images?.maybe(item.backdrop, 1920)
                                }
                            }
                        } else {
                            item(key = "top") { Spacer(Modifier.height(OF.SafeY + 24.dp)) }
                        }
                        items(current.sections, key = { it.id }) { section ->
                            MediaRow(
                                title = section.title,
                                items = section.items,
                                style = if (section.landscape) CardStyle.Landscape else CardStyle.Poster,
                                onClick = { nav.open(it) },
                                onLongClick = { actions = it },
                                onFocus = { item -> backdrop = images?.maybe(item.backdrop ?: item.parentBackdrop, 1920) },
                            )
                        }
                    }
                }
                LaunchedEffect(current.featured.isNotEmpty()) { runCatching { firstFocus.requestFocus() } }
            }
        }
    }
    actions?.let { item ->
        ItemActionsDialog(item, onDismiss = { actions = null }, onPlay = nav.play, onDetails = { nav.details(it) })
    }
}

/** Carrousel « À la une » : fond plein écran, logo ou titre, synopsis, Lecture / Infos. */
@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun Featured(items: List<MediaItem>, nav: AppNav, modifier: Modifier, onShown: (MediaItem) -> Unit) {
    val state = rememberCarouselState()
    val images = AppServices.images
    val height = (LocalConfiguration.current.screenHeightDp * 0.72f).dp
    Carousel(
        itemCount = items.size,
        modifier = modifier.fillMaxWidth().height(height),
        carouselState = state,
        autoScrollDurationMillis = 9000,
        contentTransformStartToEnd = fadeIn(tween(600)) togetherWith fadeOut(tween(600)),
        contentTransformEndToStart = fadeIn(tween(600)) togetherWith fadeOut(tween(600)),
        carouselIndicator = {
            CarouselDefaults.IndicatorRow(
                itemCount = items.size,
                activeItemIndex = state.activeItemIndex,
                modifier = Modifier.align(Alignment.BottomStart).padding(start = OF.Gutter, bottom = 18.dp),
            )
        },
    ) { index ->
        val item = items[index]
        LaunchedEffect(item.id) { onShown(item) }
        Box(Modifier.fillMaxSize()) {
            AsyncImage(images?.maybe(item.backdrop, 1920), null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(Color(0xE6000000), Color(0x66000000), Color.Transparent))))
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.55f to Color.Transparent, 1f to Color.Black)))
            AnimatedContent(item, transitionSpec = { (fadeIn(tween(500)) + slideInVertically { it / 12 }) togetherWith fadeOut(tween(300)) }, label = "infos") { shown ->
                Column(
                    Modifier.fillMaxSize().padding(start = OF.Gutter, bottom = 56.dp, end = OF.Gutter),
                    verticalArrangement = Arrangement.Bottom,
                ) {
                    val logo = images?.maybe(shown.logo, 800)
                    if (logo != null) {
                        AsyncImage(logo, shown.name, contentScale = ContentScale.Fit, alignment = Alignment.BottomStart,
                            modifier = Modifier.widthIn(max = 460.dp).heightIn(max = 150.dp))
                    } else {
                        Text(shown.name, style = MaterialTheme.typography.displayMedium, maxLines = 2, overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.widthIn(max = 760.dp))
                    }
                    Spacer(Modifier.height(14.dp))
                    val meta = (shown.genres.take(2).map { it.name } + MediaFormat.metadataLine(shown)).joinToString(" · ")
                    if (meta.isNotEmpty()) Text(meta, style = MaterialTheme.typography.titleSmall, color = OF.TextSecondary)
                    shown.overview?.let {
                        Spacer(Modifier.height(10.dp))
                        Text(it, style = MaterialTheme.typography.bodyLarge, maxLines = 3, overflow = TextOverflow.Ellipsis,
                            color = OF.TextPrimary, modifier = Modifier.widthIn(max = 720.dp))
                    }
                    Spacer(Modifier.height(22.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        TvButton(if (shown.kind == MediaKind.Series) "Regarder" else "Lecture",
                            { if (shown.kind.isPlayableVideo) nav.play(shown.id, false) else nav.details(shown.id) },
                            icon = Icons.Rounded.PlayArrow, primary = true)
                        TvButton("Infos", { nav.details(shown.id) }, icon = Icons.Rounded.Info)
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeSkeleton() {
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.padding(start = OF.Gutter, top = 220.dp)) {
            Skeleton(Modifier.width(420.dp).height(90.dp))
            Spacer(Modifier.height(18.dp))
            Skeleton(Modifier.width(600.dp).height(18.dp), 6.dp)
            Spacer(Modifier.height(10.dp))
            Skeleton(Modifier.width(520.dp).height(18.dp), 6.dp)
            Spacer(Modifier.height(24.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Skeleton(Modifier.width(150.dp).height(50.dp), 25.dp)
                Skeleton(Modifier.width(120.dp).height(50.dp), 25.dp)
            }
        }
        Spacer(Modifier.height(60.dp))
        SkeletonRow(CardStyle.Landscape)
    }
}
