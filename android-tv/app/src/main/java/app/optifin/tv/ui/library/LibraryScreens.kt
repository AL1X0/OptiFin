package app.optifin.tv.ui.library

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.FilterList
import androidx.compose.material.icons.rounded.SortByAlpha
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusRestorer
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Icon
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.LibraryFilterOptions
import app.optifin.tv.core.media.LibraryQuery
import app.optifin.tv.core.media.LibrarySort
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.core.media.ResolutionFilter
import app.optifin.tv.ui.components.CardStyle
import app.optifin.tv.ui.components.ItemActionsDialog
import app.optifin.tv.ui.components.MediaCard
import app.optifin.tv.ui.components.MenuRow
import app.optifin.tv.ui.components.Skeleton
import app.optifin.tv.ui.components.StatusMessage
import app.optifin.tv.ui.components.TvButton
import app.optifin.tv.ui.components.TvDialog
import app.optifin.tv.ui.home.open
import app.optifin.tv.ui.shell.AppNav
import app.optifin.tv.ui.theme.OF
import app.optifin.tv.ui.theme.PivotSpec
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch

/** Bibliothèques de l'utilisateur (cartes paysage). */
@Composable
fun LibrariesScreen(nav: AppNav) {
    var libraries by remember { mutableStateOf<List<MediaItem>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val first = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        try {
            libraries = AppServices.media?.userViews()
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            error = e.userMessage()
        }
    }
    Column(Modifier.fillMaxSize().padding(top = OF.SafeY + 12.dp)) {
        Text("Bibliothèques", style = MaterialTheme.typography.displaySmall, modifier = Modifier.padding(start = OF.Gutter, bottom = 20.dp))
        val list = libraries
        when {
            list == null && error != null -> StatusMessage(error!!)
            list == null -> Row(Modifier.padding(start = OF.Gutter), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                repeat(4) { Skeleton(Modifier.width(320.dp).aspectRatio(16f / 9f)) }
            }
            list.isEmpty() -> StatusMessage("Aucune bibliothèque.")
            else -> {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(260.dp),
                    contentPadding = PaddingValues(horizontal = OF.Gutter, vertical = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(24.dp),
                    verticalArrangement = Arrangement.spacedBy(28.dp),
                ) {
                    items(list, key = { it.id }) { lib ->
                        MediaCard(lib, CardStyle.Landscape, onClick = { nav.library(lib.id) }, width = 320.dp,
                            modifier = if (lib == list.first()) Modifier.focusRequester(first) else Modifier)
                    }
                }
                LaunchedEffect(Unit) { runCatching { first.requestFocus() } }
            }
        }
    }
}

private const val PAGE = 60
private val LETTERS = listOf("#") + ('A'..'Z').map { it.toString() }

/**
 * Une bibliothèque : grille chargée par pages au fil du défilement ; tri, sens, filtres (vus,
 * favoris, genres, années, résolution) et saut à une lettre.
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
fun LibraryScreen(id: String, nav: AppNav) {
    val scope = rememberCoroutineScope()
    var library by remember(id) { mutableStateOf<MediaItem?>(null) }
    var query by remember(id) { mutableStateOf<LibraryQuery?>(null) }
    val items = remember(id) { mutableStateListOf<MediaItem?>() }
    var total by remember(id) { mutableIntStateOf(-1) }
    val loading = remember(id) { mutableSetOf<Int>() }
    var generation by remember(id) { mutableIntStateOf(0) }
    var error by remember(id) { mutableStateOf<String?>(null) }
    var dialog by remember { mutableStateOf<String?>(null) }
    var filters by remember(id) { mutableStateOf<LibraryFilterOptions?>(null) }
    var actions by remember { mutableStateOf<MediaItem?>(null) }
    val grid = rememberLazyGridState()
    val firstFocus = remember { FocusRequester() }

    LaunchedEffect(id) {
        try {
            val lib = AppServices.media?.item(id) ?: return@LaunchedEffect
            library = lib
            query = LibraryQuery.forLibrary(lib)
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            error = e.userMessage()
        }
    }

    fun loadPage(page: Int) {
        val q = query ?: return
        val media = AppServices.media ?: return
        if (!loading.add(page)) return
        val gen = generation
        scope.launch {
            try {
                val r = media.page(q, page * PAGE, PAGE)
                if (gen != generation) return@launch
                if (total < 0 || items.size != r.total) {
                    total = r.total
                    while (items.size < r.total) items.add(null)
                    while (items.size > r.total) items.removeAt(items.lastIndex)
                }
                r.items.forEachIndexed { i, item -> if (page * PAGE + i < items.size) items[page * PAGE + i] = item }
                error = null
            } catch (e: kotlinx.coroutines.CancellationException) {
                loading.remove(page)
                throw e
            } catch (e: Exception) {
                loading.remove(page)
                if (items.isEmpty()) error = e.userMessage()
            }
        }
    }

    // Nouvelle requête (tri, filtres) : liste remise à zéro.
    LaunchedEffect(query) {
        if (query == null) return@LaunchedEffect
        generation++
        loading.clear()
        items.clear()
        total = -1
        grid.scrollToItem(0)
        loadPage(0)
    }
    // Pages chargées à l'approche de la zone visible.
    LaunchedEffect(grid, query) {
        snapshotFlow { grid.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0 }
            .distinctUntilChanged()
            .collect { last ->
                val first = grid.firstVisibleItemIndex
                for (page in (first / PAGE)..((last + 20) / PAGE)) if (page * PAGE < maxOf(total, PAGE)) loadPage(page)
            }
    }

    val lib = library
    val q = query
    val style = when {
        q?.kinds?.any { it == MediaKind.MusicAlbum } == true -> CardStyle.Square
        q?.kinds?.isNotEmpty() == true && q.kinds.all { it.prefersPoster } -> CardStyle.Poster
        else -> CardStyle.Landscape
    }

    Column(Modifier.fillMaxSize().padding(top = OF.SafeY + 8.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = OF.Gutter), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(Modifier.weight(1f)) {
                Text(lib?.name ?: "", style = MaterialTheme.typography.displaySmall)
                if (total >= 0) Text("$total titre${if (total > 1) "s" else ""}", style = MaterialTheme.typography.bodyMedium, color = OF.TextTertiary)
            }
            if (q != null) {
                TvButton("${q.sort.label} ${if (q.descending) "↓" else "↑"}", { dialog = "sort" }, icon = Icons.Rounded.SwapVert)
                TvButton(if (q.activeFilterCount > 0) "Filtres (${q.activeFilterCount})" else "Filtres", {
                    dialog = "filters"
                    if (filters == null) scope.launch { filters = runCatching { AppServices.media?.filterOptions(q) }.getOrNull() }
                }, icon = Icons.Rounded.FilterList)
                if (q.sort == LibrarySort.Title && !q.descending) TvButton("A-Z", { dialog = "letters" }, icon = Icons.Rounded.SortByAlpha)
            }
        }
        Spacer(Modifier.height(12.dp))
        when {
            error != null && items.isEmpty() -> StatusMessage(error!!, action = "Réessayer", onAction = { generation++; loading.clear(); loadPage(0) })
            total == 0 -> StatusMessage(if ((q?.activeFilterCount ?: 0) > 0) "Aucun titre ne correspond à ces filtres." else "Cette bibliothèque est vide.")
            else -> {
                val pivot = remember { PivotSpec(0.18f) }
                CompositionLocalProvider(LocalBringIntoViewSpec provides pivot) {
                    LazyVerticalGrid(
                        state = grid,
                        columns = GridCells.Adaptive(style.width),
                        modifier = Modifier.focusRestorer(firstFocus),
                        contentPadding = PaddingValues(horizontal = OF.Gutter, vertical = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(22.dp),
                        verticalArrangement = Arrangement.spacedBy(26.dp),
                    ) {
                        items(items.size, key = { i -> items[i]?.id?.let { "$it-$i" } ?: "vide-$i" }) { i ->
                            val item = items[i]
                            if (item == null) {
                                Column {
                                    Skeleton(Modifier.fillMaxWidth().aspectRatio(style.ratio))
                                    Spacer(Modifier.height(48.dp))
                                }
                            } else {
                                MediaCard(item, style, onClick = { nav.open(item) }, onLongClick = { actions = item }, width = style.width,
                                    modifier = if (i == 0) Modifier.focusRequester(firstFocus) else Modifier)
                            }
                        }
                    }
                }
                LaunchedEffect(items.firstOrNull() != null) { if (items.firstOrNull() != null) runCatching { firstFocus.requestFocus() } }
            }
        }
    }

    if (q != null) when (dialog) {
        "sort" -> TvDialog("Trier par", { dialog = null }) {
            LazyColumn(Modifier.heightIn(max = 520.dp)) {
                items(LibrarySort.entries) { sort ->
                    val selected = sort == q.sort
                    MenuRow(
                        sort.label + if (selected) "  ${if (q.descending) "↓ décroissant" else "↑ croissant"}" else "",
                        {
                            query = if (selected) q.copy(descending = !q.descending) else q.copy(sort = sort, descending = sort.defaultDescending)
                            dialog = null
                        },
                        selected = selected, trailing = if (selected) { { Icon(Icons.Rounded.Check, null) } } else null,
                    )
                }
            }
        }
        "filters" -> FiltersDialog(q, filters, onChange = { query = it }, onDismiss = { dialog = null })
        "letters" -> TvDialog("Aller à la lettre", { dialog = null }) {
            LazyVerticalGrid(GridCells.Fixed(7), Modifier.heightIn(max = 420.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(LETTERS) { letter ->
                    TvButton(letter, {
                        dialog = null
                        scope.launch {
                            val index = runCatching { AppServices.media?.indexOfLetter(q, letter) }.getOrNull() ?: return@launch
                            if (index < items.size) {
                                loadPage(index / PAGE)
                                grid.scrollToItem(index)
                            }
                        }
                    })
                }
            }
        }
    }
    actions?.let { ItemActionsDialog(it, onDismiss = { actions = null }, onPlay = nav.play, onDetails = { d -> nav.details(d) }) }
}

/** Filtres : vus / non vus, favoris, genres, années, résolution. */
@Composable
private fun FiltersDialog(q: LibraryQuery, options: LibraryFilterOptions?, onChange: (LibraryQuery) -> Unit, onDismiss: () -> Unit) {
    TvDialog("Filtres", onDismiss) {
        LazyColumn(Modifier.heightIn(max = 560.dp)) {
            item {
                MenuRow("Vus", { onChange(q.copy(played = when (q.played) { null -> false; false -> true; true -> null })) },
                    supporting = when (q.played) { null -> "Tous"; false -> "Non vus"; true -> "Vus" })
            }
            item {
                MenuRow("Favoris uniquement", { onChange(q.copy(favoritesOnly = !q.favoritesOnly)) },
                    trailing = if (q.favoritesOnly) { { Icon(Icons.Rounded.Check, null) } } else null)
            }
            item {
                MenuRow("Résolution", {
                    val all = ResolutionFilter.entries
                    onChange(q.copy(resolution = all[(all.indexOf(q.resolution) + 1) % all.size]))
                }, supporting = q.resolution.label)
            }
            if (q.activeFilterCount > 0) item { MenuRow("Réinitialiser les filtres", { onChange(LibraryQuery(q.parentId, q.kinds, q.recursive, q.sort, q.descending)) }) }
            if (options == null) item { Text("Chargement des genres…", style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary, modifier = Modifier.padding(12.dp)) }
            options?.let { o ->
                if (o.genres.isNotEmpty()) item { Text("Genres", style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 14.dp)) }
                items(o.genres, key = { "g" + it.id }) { g ->
                    val on = g.id in q.genreIds
                    MenuRow(g.name, { onChange(q.copy(genreIds = if (on) q.genreIds - g.id else q.genreIds + g.id)) },
                        trailing = if (on) { { Icon(Icons.Rounded.Check, null) } } else null)
                }
                if (o.years.isNotEmpty()) item { Text("Années", style = MaterialTheme.typography.titleSmall, color = OF.TextTertiary, modifier = Modifier.padding(start = 12.dp, top = 14.dp)) }
                items(o.years, key = { "y$it" }) { y ->
                    val on = y in q.years
                    MenuRow(y.toString(), { onChange(q.copy(years = if (on) q.years - y else q.years + y)) },
                        trailing = if (on) { { Icon(Icons.Rounded.Check, null) } } else null)
                }
            }
        }
    }
}
