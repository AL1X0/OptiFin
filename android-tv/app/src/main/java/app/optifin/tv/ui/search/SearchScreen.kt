package app.optifin.tv.ui.search

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import app.optifin.tv.AppServices
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.SearchResults
import app.optifin.tv.ui.components.CardStyle
import app.optifin.tv.ui.components.ItemActionsDialog
import app.optifin.tv.ui.components.MediaRow
import app.optifin.tv.ui.components.StatusMessage
import app.optifin.tv.ui.components.TvIconButton
import app.optifin.tv.ui.components.TvTextField
import app.optifin.tv.ui.home.open
import app.optifin.tv.ui.shell.AppNav
import app.optifin.tv.ui.theme.OF
import app.optifin.tv.ui.theme.PivotSpec
import kotlinx.coroutines.delay

/** Recherche dans toutes les bibliothèques : clavier de la télécommande ou recherche vocale. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SearchScreen(nav: AppNav) {
    var term by rememberSaveable { mutableStateOf("") }
    var results by remember { mutableStateOf<SearchResults?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var searching by remember { mutableStateOf(false) }
    var actions by remember { mutableStateOf<MediaItem?>(null) }
    val field = remember { FocusRequester() }
    val context = LocalContext.current
    val voice = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { r ->
        if (r.resultCode == Activity.RESULT_OK) {
            r.data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()?.let { term = it }
        }
    }
    val voiceAvailable = remember {
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).resolveActivity(context.packageManager) != null
    }

    LaunchedEffect(term) {
        val t = term.trim()
        if (t.length < 2) {
            results = null
            error = null
            return@LaunchedEffect
        }
        delay(350)
        searching = true
        try {
            results = AppServices.media?.search(t)
            error = null
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Exception) {
            error = e.userMessage()
        } finally {
            searching = false
        }
    }
    LaunchedEffect(Unit) { runCatching { field.requestFocus() } }

    Column(Modifier.fillMaxSize().padding(top = OF.SafeY + 8.dp)) {
        Row(Modifier.padding(horizontal = OF.Gutter), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            TvTextField(term, { term = it }, "Films, séries, épisodes, personnes…", Modifier.weight(1f), imeAction = ImeAction.Search, focusRequester = field)
            if (voiceAvailable) {
                TvIconButton(Icons.Rounded.Mic, "Recherche vocale", {
                    voice.launch(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                        .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        .putExtra(RecognizerIntent.EXTRA_PROMPT, "Que voulez-vous regarder ?"))
                })
            }
        }
        val r = results
        when {
            error != null -> StatusMessage(error!!)
            r == null -> StatusMessage(if (searching) "Recherche…" else "Tapez au moins deux lettres, ou utilisez le micro de la télécommande.")
            r.isEmpty -> StatusMessage("Aucun résultat pour « ${term.trim()} ».")
            else -> {
                val pivot = remember { PivotSpec(0.3f) }
                CompositionLocalProvider(LocalBringIntoViewSpec provides pivot) {
                    LazyColumn(contentPadding = PaddingValues(top = 24.dp, bottom = 64.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
                        fun row(key: String, title: String, items: List<MediaItem>, style: CardStyle) {
                            if (items.isNotEmpty()) item(key = key) {
                                MediaRow(title, items, style, onClick = { nav.open(it) }, onLongClick = { actions = it })
                            }
                        }
                        row("movies", "Films", r.movies, CardStyle.Poster)
                        row("series", "Séries", r.series, CardStyle.Poster)
                        row("episodes", "Épisodes", r.episodes, CardStyle.Landscape)
                        row("people", "Personnes", r.people, CardStyle.Person)
                        row("others", "Autres", r.others, CardStyle.Poster)
                    }
                }
            }
        }
    }
    actions?.let { ItemActionsDialog(it, onDismiss = { actions = null }, onPlay = nav.play, onDetails = { d -> nav.details(d) }) }
}
