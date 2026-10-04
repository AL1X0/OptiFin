package app.optifin.tv.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Replay
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.tv.material3.Icon
import androidx.tv.material3.ListItem
import androidx.tv.material3.ListItemDefaults
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.core.api.userMessage
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.ui.theme.OF
import kotlinx.coroutines.launch

/** Ligne de menu TV (fenêtre, panneau). */
@Composable
fun MenuRow(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    supporting: String? = null,
    selected: Boolean = false,
    trailing: (@Composable () -> Unit)? = null,
) {
    ListItem(
        selected = selected,
        onClick = onClick,
        modifier = modifier,
        headlineContent = { Text(label, style = MaterialTheme.typography.titleMedium) },
        supportingContent = supporting?.let { { Text(it, style = MaterialTheme.typography.bodySmall) } },
        leadingContent = icon?.let { { Icon(it, null) } },
        trailingContent = trailing,
        colors = ListItemDefaults.colors(
            containerColor = Color.Transparent, focusedContainerColor = Color.White,
            selectedContainerColor = Color(0x24FFFFFF), contentColor = OF.TextPrimary, focusedContentColor = Color.Black,
            selectedContentColor = OF.TextPrimary,
        ),
        shape = ListItemDefaults.shape(RoundedCornerShape(12.dp)),
    )
}

/** Fenêtre centrée façon TV (fond sombre, liste d'actions), fermée par Retour. */
@Composable
fun TvDialog(title: String, onDismiss: () -> Unit, subtitle: String? = null, content: @Composable () -> Unit) {
    Dialog(onDismissRequest = onDismiss) {
        Column(
            Modifier.width(560.dp).clip(RoundedCornerShape(24.dp)).background(Color(0xFA1C1C20)).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(title, style = MaterialTheme.typography.headlineSmall, color = OF.TextPrimary, maxLines = 2)
            subtitle?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = OF.TextSecondary) }
            Spacer(Modifier.height(10.dp))
            content()
        }
    }
}

/**
 * Actions d'un élément (appui long sur une carte) : lecture, reprendre du début, fiche, série,
 * vu / non vu, favori. Les écrans se rafraîchissent ensuite.
 */
@Composable
fun ItemActionsDialog(item: MediaItem, onDismiss: () -> Unit, onPlay: (String, Boolean) -> Unit, onDetails: (String) -> Unit) {
    val scope = rememberCoroutineScope()
    val first = remember { FocusRequester() }
    fun update(action: suspend () -> Unit, done: String) {
        scope.launch {
            try {
                action()
                AppServices.notice(done)
                AppServices.notifyChanged(item.id)
            } catch (e: Exception) {
                AppServices.notice(e.userMessage())
            }
            onDismiss()
        }
    }
    TvDialog(item.name, onDismiss, subtitle = item.episodeLabel ?: item.year?.toString()) {
        val media = AppServices.media
        if (item.kind.isPlayableVideo) {
            val resume = item.user.positionTicks > 0
            MenuRow(if (resume) "Reprendre" else "Lecture", { onDismiss(); onPlay(item.id, false) }, Modifier.focusRequester(first), Icons.Rounded.PlayArrow)
            if (resume) MenuRow("Lire depuis le début", { onDismiss(); onPlay(item.id, true) }, icon = Icons.Rounded.Replay)
        }
        MenuRow("Afficher la fiche", { onDismiss(); onDetails(item.id) },
            if (!item.kind.isPlayableVideo) Modifier.focusRequester(first) else Modifier, Icons.Rounded.Info)
        val seriesId = item.seriesId
        if ((item.kind == MediaKind.Episode || item.kind == MediaKind.Season) && seriesId != null) {
            MenuRow("Voir la série", { onDismiss(); onDetails(seriesId) }, icon = Icons.Rounded.Tv)
        }
        if (media != null && item.kind != MediaKind.Person && item.kind != MediaKind.CollectionFolder) {
            if (item.kind != MediaKind.BoxSet) {
                MenuRow(
                    if (item.user.played) "Marquer comme non vu" else "Marquer comme vu",
                    { update({ media.setPlayed(item.id, !item.user.played) }, if (item.user.played) "Marqué comme non vu" else "Marqué comme vu") },
                    icon = if (item.user.played) Icons.Rounded.RadioButtonUnchecked else Icons.Rounded.CheckCircle,
                )
            }
            MenuRow(
                if (item.user.favorite) "Retirer des favoris" else "Ajouter aux favoris",
                { update({ media.setFavorite(item.id, !item.user.favorite) }, if (item.user.favorite) "Retiré des favoris" else "Ajouté aux favoris") },
                icon = if (item.user.favorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
            )
        }
    }
    LaunchedEffect(Unit) { runCatching { first.requestFocus() } }
}
