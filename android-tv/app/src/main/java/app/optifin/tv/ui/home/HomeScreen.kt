package app.optifin.tv.ui.home

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.animation.animateColorAsState
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Shadow
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.gestures.BringIntoViewSpec
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.rounded.ChevronLeft
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.currentStateAsState
import app.optifin.tv.ui.components.TvIconButton
import coil3.request.crossfade
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull
import app.optifin.tv.core.L
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
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
import androidx.compose.material.icons.rounded.Shuffle
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
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
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
import app.optifin.tv.ui.components.TitleLogo
import app.optifin.tv.ui.components.TvButton
import app.optifin.tv.ui.shell.AppNav
import app.optifin.tv.ui.theme.OF
import app.optifin.tv.ui.theme.PivotSpec
import app.optifin.tv.ui.theme.screenHeight
import coil3.SingletonImageLoader
import coil3.compose.AsyncImage
import coil3.request.ImageRequest
import coil3.size.Size
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
    var surprise by remember { mutableStateOf(false) }
    var heroFocused by remember { mutableStateOf(false) }
    // Dernière zone utilisée de la page : ouvrir le menu ne change donc pas le fond.
    var onRows by remember { mutableStateOf(false) }
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
                    // Écran d'accueil Android TV : « Continuer à regarder » à jour (données fraîches seulement).
                    if (!it.fromCache) {
                        if (AppServices.settings.value.watchNext) {
                            app.optifin.tv.core.WatchNext.update(AppServices.context,
                                it.sections.firstOrNull { s -> s.id == "resume" }?.items.orEmpty(),
                                it.sections.firstOrNull { s -> s.id == "nextup" }?.items.orEmpty(), AppServices.images)
                        } else app.optifin.tv.core.WatchNext.clear(AppServices.context)
                    }
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
        HomeBackdrop(backdrop, onRows)
        val current = data
        when {
            current == null && error != null -> StatusMessage(error!!, action = L.t("Réessayer"), onAction = ::load)
            current == null -> HomeSkeleton()
            current.isEmpty -> StatusMessage(L.t("Votre serveur ne contient encore rien à afficher."))
            else -> {
                // Focus dans le bandeau : la page reste en haut. Sinon, dès qu'un bouton changeait de libellé
                // au changement de titre, le défilement cherchait à l'amener au pivot et la page descendait seule.
                val pivot = remember {
                    val rows = PivotSpec(0.1f)
                    object : BringIntoViewSpec by rows {
                        override fun calculateScrollDistance(offset: Float, size: Float, containerSize: Float) =
                            if (heroFocused) 0f else rows.calculateScrollDistance(offset, size, containerSize)
                    }
                }
                val list = androidx.compose.foundation.lazy.rememberLazyListState()
                val firstFocus = remember { FocusRequester() }
                CompositionLocalProvider(LocalBringIntoViewSpec provides pivot) {
                    LazyColumn(
                        state = list,
                        modifier = Modifier.fillMaxSize().focusRestorer(firstFocus),
                        contentPadding = PaddingValues(bottom = 80.dp),
                        verticalArrangement = Arrangement.spacedBy(28.dp),
                    ) {
                        if (current.featured.isNotEmpty()) {
                            item(key = "featured") {
                                // Retour sur le bandeau : la page remonte tout en haut.
                                val atTop by remember { derivedStateOf { list.firstVisibleItemIndex == 0 } }
                                val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
                                Hero(current.featured, nav, firstFocus, Modifier.onFocusChanged {
                                    heroFocused = it.hasFocus
                                    if (it.hasFocus) onRows = false
                                    if (it.hasFocus) scope.launch { list.animateScrollToItem(0) }
                                }, active = heroFocused && atTop && !surprise && actions == null && lifecycle.isAtLeast(Lifecycle.State.RESUMED), onSurprise = { surprise = true }) { item ->
                                    backdrop = images?.maybe(item.backdrop, 1920)
                                }
                            }
                        } else {
                            item(key = "top") { Spacer(Modifier.height(OF.SafeY + 24.dp)) }
                        }
                        items(current.sections, key = { it.id }) { section ->
                            // ▲ depuis la première rangée : toujours sur Lecture, quelle que soit la carte.
                            val toHero = current.featured.isNotEmpty() && section === current.sections.first()
                            MediaRow(
                                modifier = Modifier.onFocusChanged { if (it.hasFocus) onRows = true }.then(if (!toHero) Modifier else Modifier.onPreviewKeyEvent { e ->
                                    if (e.key != Key.DirectionUp) return@onPreviewKeyEvent false
                                    if (e.type == KeyEventType.KeyDown) runCatching { firstFocus.requestFocus() }
                                    true
                                }),
                                title = section.title,
                                items = section.items,
                                style = if (section.landscape) CardStyle.Landscape else CardStyle.Poster,
                                onClick = { nav.open(it) },
                                onLongClick = { actions = it },
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
    if (surprise) SurpriseDialog(onDismiss = { surprise = false }, onDetails = { nav.details(it) })
}

/**
 * Image en plein écran derrière toute la page ; l'ancienne reste opaque sous la nouvelle. Dégradés étendus à tout
 * l'écran, donc sans bord visible : sombres derrière le texte à gauche et sous les rangées, l'image reste nette à
 * droite. Sur les rangées, fond noir uni : l'image ne revient qu'en remontant sur le bandeau.
 */
@Composable
private fun HomeBackdrop(url: String?, onRows: Boolean) {
    val context = LocalContext.current
    val black by animateFloatAsState(if (onRows) 1f else 0f, tween(300), label = "noir")
    Box(Modifier.fillMaxSize().background(OF.Background)) {
        AnimatedContent(url, transitionSpec = { fadeIn(tween(500)) togetherWith fadeOut(snap(delayMillis = 500)) }, label = "image") { target ->
            if (target != null) {
                AsyncImage(
                    ImageRequest.Builder(context).data(target).size(Size.ORIGINAL).crossfade(false).build(),
                    null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize(),
                )
            } else Box(Modifier.fillMaxSize())
        }
        Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(0f to Color(0xE6000000), 0.35f to Color(0xA6000000), 0.65f to Color(0x33000000), 1f to Color.Transparent)))
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to Color(0x33000000), 0.3f to Color.Transparent, 0.62f to Color(0x59000000), 1f to Color(0xF2000000))))
        Box(Modifier.fillMaxSize().alpha(black).background(Color.Black))
    }
}

/** Ombre des textes posés directement sur l'image. */
private val TextShadow = Shadow(Color(0xCC000000), Offset(0f, 2f), 10f)

/** Sélection à la une : stable pendant 30 min, sinon elle changeait à chaque retour d'une fiche. */
private object HeroMemory {
    var account: String? = null
    var items: List<MediaItem> = emptyList()
    var shownId: String? = null
    var pickedAt = 0L

    fun itemsFor(account: String?, fresh: List<MediaItem>): List<MediaItem> {
        val now = System.currentTimeMillis()
        if (account != this.account || items.isEmpty() || now - pickedAt > 30 * 60_000L) {
            this.account = account
            items = fresh
            shownId = null
            pickedAt = now
        }
        return items
    }
}

private const val HERO_SECONDS = 9L

/**
 * Bandeau « À la une », pensé pour la télécommande : les boutons ne changent jamais de place et gardent le focus,
 * ‹ › changent de titre (◀ reste le chemin vers le menu). L'image suivante est chargée avant d'être affichée, et
 * posée sur l'ancienne : jamais d'écran noir. Défilement tant que le bandeau est visible et sans fenêtre ouverte.
 */
@Composable
private fun Hero(fresh: List<MediaItem>, nav: AppNav, playFocus: FocusRequester, modifier: Modifier, active: Boolean, onSurprise: () -> Unit, onShown: (MediaItem) -> Unit) {
    val images = AppServices.images
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val account = AppServices.session.value?.account?.id
    val items = remember(account, fresh) { HeroMemory.itemsFor(account, fresh) }
    var shownId by remember(items) { mutableStateOf(HeroMemory.shownId?.takeIf { id -> items.any { it.id == id } } ?: items.first().id) }
    val index = items.indexOfFirst { it.id == shownId }.coerceAtLeast(0)
    val item = items[index]
    var aim by remember(items) { mutableIntStateOf(index) }
    var loading by remember { mutableStateOf<Job?>(null) }

    fun requestsFor(target: MediaItem) = listOfNotNull(images?.maybe(target.backdrop, 1920), images?.maybe(target.logo, 800))
        .map { ImageRequest.Builder(context).data(it).size(Size.ORIGINAL).build() }

    fun go(step: Int) {
        aim = (aim + step).mod(items.size)
        val target = items[aim]
        loading?.cancel()
        loading = scope.launch {
            val loader = SingletonImageLoader.get(context)
            // Serveur lent : le titre change quand même, sans attendre indéfiniment.
            withTimeoutOrNull(5000) { requestsFor(target).forEach { loader.execute(it) } }
            shownId = target.id
        }
    }

    LaunchedEffect(item.id) {
        HeroMemory.shownId = item.id
        onShown(item)
        // Voisins préparés d'avance : le changement est alors immédiat.
        val loader = SingletonImageLoader.get(context)
        listOf(1, -1).forEach { step -> requestsFor(items[(index + step).mod(items.size)]).forEach(loader::enqueue) }
    }
    LaunchedEffect(item.id, active) {
        if (!active || items.size < 2) return@LaunchedEffect
        delay(HERO_SECONDS * 1000)
        go(1)
    }

    Box(modifier.fillMaxWidth().height(screenHeight() * 0.8f)) {
        Column(Modifier.align(Alignment.BottomStart).padding(start = OF.Gutter, end = OF.Gutter, bottom = 14.dp)) {
            AnimatedContent(item, transitionSpec = { fadeIn(tween(350)) togetherWith fadeOut(tween(200)) }, contentKey = { it.id }, contentAlignment = Alignment.BottomStart, label = "infos") { shown ->
                Column(Modifier.height(214.dp).fillMaxWidth(), verticalArrangement = Arrangement.Bottom) {
                    TitleLogo(images?.maybe(shown.logo, 800), shown.name, maxWidth = 400.dp, maxHeight = 120.dp)
                    Spacer(Modifier.height(10.dp))
                    val meta = (shown.genres.take(2).map { it.name } + MediaFormat.metadataLine(shown)).joinToString(" · ")
                    if (meta.isNotEmpty()) Text(meta, style = MaterialTheme.typography.titleSmall.copy(shadow = TextShadow), color = OF.TextPrimary, maxLines = 1)
                    shown.overview?.let {
                        Spacer(Modifier.height(6.dp))
                        Text(it, style = MaterialTheme.typography.bodyMedium.copy(shadow = TextShadow), maxLines = 2, overflow = TextOverflow.Ellipsis,
                            color = OF.TextPrimary, modifier = Modifier.widthIn(max = 640.dp))
                    }
                }
            }
            Spacer(Modifier.height(14.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                TvButton(if (item.kind == MediaKind.Series) L.t("Regarder") else L.t("Lecture"),
                    { if (item.kind.isPlayableVideo) nav.play(item.id, false) else nav.details(item.id) },
                    Modifier.focusRequester(playFocus), icon = Icons.Rounded.PlayArrow, primary = true)
                TvButton(L.t("Infos"), { nav.details(item.id) }, icon = Icons.Rounded.Info)
                TvButton(L.t("Surprends-moi"), onSurprise, icon = Icons.Rounded.Shuffle)
                if (items.size > 1) {
                    Spacer(Modifier.width(8.dp))
                    TvIconButton(Icons.Rounded.ChevronLeft, L.t("Titre précédent"), { go(-1) })
                    TvIconButton(Icons.Rounded.ChevronRight, L.t("Titre suivant"), { go(1) })
                    Spacer(Modifier.width(8.dp))
                    items.indices.forEach { i ->
                        Box(Modifier.padding(horizontal = 3.dp).size(if (i == index) 8.dp else 6.dp).clip(CircleShape)
                            .background(if (i == index) Color.White else Color(0x66FFFFFF)))
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
