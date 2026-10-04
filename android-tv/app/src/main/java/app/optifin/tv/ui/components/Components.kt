package app.optifin.tv.ui.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.focusRestorer
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Border
import androidx.tv.material3.Button
import androidx.tv.material3.ButtonDefaults
import androidx.tv.material3.Card
import androidx.tv.material3.CardDefaults
import androidx.tv.material3.Icon
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.core.media.MediaItem
import app.optifin.tv.core.media.MediaKind
import app.optifin.tv.ui.theme.LocalAccent
import app.optifin.tv.ui.theme.OF
import app.optifin.tv.ui.theme.PivotSpec
import coil3.compose.AsyncImage

enum class CardStyle(val width: Dp, val ratio: Float) {
    Poster(152.dp, 2f / 3f),
    Landscape(272.dp, 16f / 9f),
    Square(176.dp, 1f),
    Person(132.dp, 2f / 3f),
}

/** Titre et sous-titre affichés sous une carte. */
fun cardTitle(item: MediaItem, style: CardStyle): String =
    if (item.kind == MediaKind.Episode && style == CardStyle.Landscape && item.seriesName != null) item.seriesName else item.name

fun cardSubtitle(item: MediaItem, style: CardStyle): String? = when {
    item.kind == MediaKind.Episode -> if (style == CardStyle.Landscape) listOfNotNull(item.episodeLabel, item.name).joinToString(" · ") else item.episodeLabel
    item.kind == MediaKind.Series && (item.user.unplayedCount ?: 0) > 0 -> {
        val n = item.user.unplayedCount!!
        "$n épisode${if (n > 1) "s" else ""} non vu${if (n > 1) "s" else ""}"
    }
    item.kind == MediaKind.Person -> item.overview?.takeIf { false }
    else -> item.year?.toString()
}

/**
 * Carte d'un élément : image (affiche, paysage, carré), progression, pastille « vu ». Au focus :
 * zoom doux, liseré blanc et halo (composants TV de Google) ; titre dessous.
 */
@Composable
fun MediaCard(
    item: MediaItem,
    style: CardStyle,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onLongClick: (() -> Unit)? = null,
    onFocus: ((MediaItem) -> Unit)? = null,
    width: Dp = style.width,
    showTitle: Boolean = true,
) {
    val images = AppServices.images
    val density = LocalDensity.current
    val px = with(density) { width.roundToPx() }
    val ref = when (style) {
        CardStyle.Landscape -> item.landscape
        else -> item.poster ?: item.primary
    }
    val url = images?.maybe(ref, (px * 1.2f).toInt())
    Column(modifier.width(width)) {
        Card(
            onClick = onClick,
            onLongClick = onLongClick,
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(style.ratio)
                .onFocusChanged { if (it.isFocused) onFocus?.invoke(item) },
            shape = CardDefaults.shape(RoundedCornerShape(10.dp)),
            scale = CardDefaults.scale(focusedScale = 1.08f),
            border = CardDefaults.border(focusedBorder = Border(BorderStroke(3.dp, Color.White), shape = RoundedCornerShape(10.dp))),
            colors = CardDefaults.colors(containerColor = OF.SurfaceRaised),
        ) {
            Box(Modifier.fillMaxSize()) {
                if (url != null) {
                    AsyncImage(model = url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                } else {
                    Text(
                        item.name, style = MaterialTheme.typography.titleSmall, color = OF.TextSecondary, textAlign = TextAlign.Center,
                        modifier = Modifier.align(Alignment.Center).padding(12.dp), maxLines = 4,
                    )
                }
                item.user.progress?.let { progress -> ProgressLine(progress, Modifier.align(Alignment.BottomCenter).padding(10.dp)) }
                if (item.user.played && item.kind != MediaKind.Series && item.kind != MediaKind.Season) {
                    Box(
                        Modifier.align(Alignment.TopEnd).padding(8.dp).size(26.dp).clip(CircleShape).background(Color(0xCC000000)),
                        contentAlignment = Alignment.Center,
                    ) { Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(16.dp)) }
                }
            }
        }
        if (showTitle) {
            Spacer(Modifier.height(10.dp))
            Text(cardTitle(item, style), style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis, color = OF.TextPrimary)
            cardSubtitle(item, style)?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = OF.TextTertiary, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
fun ProgressLine(progress: Double, modifier: Modifier = Modifier, color: Color = LocalAccent.current) {
    Box(modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color(0x55FFFFFF))) {
        Box(Modifier.fillMaxHeight().fillMaxWidth(progress.toFloat().coerceIn(0f, 1f)).background(color))
    }
}

/**
 * Rangée horizontale (titre + cartes). L'élément focalisé reste aligné sur la marge gauche ;
 * revenir dans la rangée retrouve la dernière carte visitée.
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalComposeUiApi::class)
@Composable
fun MediaRow(
    title: String,
    items: List<MediaItem>,
    style: CardStyle,
    onClick: (MediaItem) -> Unit,
    modifier: Modifier = Modifier,
    onLongClick: ((MediaItem) -> Unit)? = null,
    onFocus: ((MediaItem) -> Unit)? = null,
) {
    val gutterPx = with(LocalDensity.current) { OF.Gutter.toPx() }
    Column(modifier) {
        Text(title, style = MaterialTheme.typography.headlineSmall, color = OF.TextPrimary, modifier = Modifier.padding(start = OF.Gutter, bottom = 14.dp))
        val rowSpec = remember(gutterPx) { PivotSpec(0f, gutterPx) }
        CompositionLocalProvider(LocalBringIntoViewSpec provides rowSpec) {
            LazyRow(
                modifier = Modifier.focusRestorer(),
                contentPadding = PaddingValues(horizontal = OF.Gutter, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                itemsIndexed(items, key = { i, it -> "${it.id}-$i" }) { _, item ->
                    MediaCard(item, style, onClick = { onClick(item) }, onLongClick = onLongClick?.let { { it(item) } }, onFocus = onFocus)
                }
            }
        }
    }
}

/** Fond d'ambiance : image en plein écran (fondu enchaîné), assombrie pour la lisibilité. */
@Composable
fun AmbientBackdrop(url: String?, modifier: Modifier = Modifier, strength: Float = 1f) {
    Box(modifier.fillMaxSize().background(OF.Background)) {
        AnimatedContent(
            targetState = url,
            transitionSpec = { fadeIn(tween(700)) togetherWith fadeOut(tween(700)) },
            label = "fond",
        ) { target ->
            if (target != null) {
                AsyncImage(model = target, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize().alpha(strength))
            } else {
                Box(Modifier.fillMaxSize())
            }
        }
        Box(Modifier.fillMaxSize().background(Brush.horizontalGradient(listOf(Color(0xF2000000), Color(0x99000000), Color(0x1A000000)))))
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to Color(0x33000000), 0.45f to Color(0x66000000), 1f to Color(0xFA000000))))
    }
}

/** Bouton TV : pilule blanche au focus, icône et libellé. */
@Composable
fun TvButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    primary: Boolean = false,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        colors = ButtonDefaults.colors(
            containerColor = if (primary) Color(0xF2FFFFFF) else Color(0x29FFFFFF),
            contentColor = if (primary) Color.Black else OF.TextPrimary,
            focusedContainerColor = Color.White,
            focusedContentColor = Color.Black,
        ),
        scale = ButtonDefaults.scale(focusedScale = 1.06f),
        contentPadding = PaddingValues(horizontal = 22.dp, vertical = 12.dp),
    ) {
        if (icon != null) {
            Icon(icon, null, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(10.dp))
        }
        Text(text, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
    }
}

/** Bouton rond (icône seule) avec libellé lu par l'accessibilité. */
@Composable
fun TvIconButton(icon: ImageVector, label: String, onClick: () -> Unit, modifier: Modifier = Modifier, tint: Color? = null) {
    Button(
        onClick = onClick,
        modifier = modifier.size(52.dp),
        shape = ButtonDefaults.shape(CircleShape),
        colors = ButtonDefaults.colors(
            containerColor = Color(0x29FFFFFF), contentColor = tint ?: OF.TextPrimary,
            focusedContainerColor = Color.White, focusedContentColor = Color.Black,
        ),
        scale = ButtonDefaults.scale(focusedScale = 1.1f),
        contentPadding = PaddingValues(0.dp),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Icon(icon, label, modifier = Modifier.size(24.dp)) }
    }
}

/** Bloc qui pulse pendant le chargement. */
@Composable
fun Skeleton(modifier: Modifier = Modifier, radius: Dp = 10.dp) {
    val transition = rememberInfiniteTransition(label = "squelette")
    val alpha by transition.animateFloat(0.35f, 0.7f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "alpha")
    Box(modifier.clip(RoundedCornerShape(radius)).background(OF.SurfaceRaised.copy(alpha = alpha)))
}

@Composable
fun SkeletonRow(style: CardStyle, modifier: Modifier = Modifier) {
    Column(modifier.padding(start = OF.Gutter)) {
        Skeleton(Modifier.width(220.dp).height(24.dp), 6.dp)
        Spacer(Modifier.height(18.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
            repeat(7) { Skeleton(Modifier.width(style.width).aspectRatio(style.ratio)) }
        }
    }
}

/** Message centré (vide, erreur) avec action facultative. */
@Composable
fun StatusMessage(text: String, modifier: Modifier = Modifier, action: String? = null, onAction: (() -> Unit)? = null) {
    Column(modifier.fillMaxSize().padding(48.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text, style = MaterialTheme.typography.titleLarge, color = OF.TextSecondary, textAlign = TextAlign.Center)
        if (action != null && onAction != null) {
            Spacer(Modifier.height(24.dp))
            TvButton(action, onAction, primary = true)
        }
    }
}

/** Badge texte (4K, HDR10, Atmos…). */
@Composable
fun Badge(text: String) {
    Box(Modifier.clip(RoundedCornerShape(6.dp)).background(Color(0x26FFFFFF)).padding(horizontal = 9.dp, vertical = 3.dp)) {
        Text(text, style = MaterialTheme.typography.labelMedium, color = OF.TextPrimary)
    }
}

/** Avatar rond (initiale si pas d'image). */
@Composable
fun Avatar(name: String, url: String?, size: Dp, modifier: Modifier = Modifier) {
    Box(modifier.size(size).clip(CircleShape).background(OF.SurfaceHigh), contentAlignment = Alignment.Center) {
        Text(name.take(1).uppercase(), style = MaterialTheme.typography.titleLarge, color = OF.TextPrimary)
        if (url != null) AsyncImage(model = url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
    }
}

@Composable
fun BoxScope.TopFade() {
    Box(Modifier.fillMaxWidth().height(120.dp).align(Alignment.TopCenter).background(Brush.verticalGradient(listOf(Color(0xB3000000), Color.Transparent))))
}

/** Logo du titre (image transparente du serveur) ; titre en texte s'il manque ou ne charge pas. */
@Composable
fun TitleLogo(url: String?, title: String, modifier: Modifier = Modifier, maxWidth: Dp = 520.dp, maxHeight: Dp = 160.dp) {
    var failed by remember(url) { mutableStateOf(url == null) }
    if (failed) {
        Text(title, style = MaterialTheme.typography.displayMedium, maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = modifier.widthIn(max = maxWidth * 1.7f))
    } else {
        AsyncImage(
            model = url, contentDescription = title, contentScale = ContentScale.Fit, alignment = Alignment.BottomStart,
            onError = { failed = true },
            modifier = modifier.widthIn(max = maxWidth).height(maxHeight),
        )
    }
}

