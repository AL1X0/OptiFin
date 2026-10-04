package app.optifin.tv.ui.theme

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.gestures.BringIntoViewSpec
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.ColorScheme
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Typography
import androidx.tv.material3.darkColorScheme

/** Couleurs OptiFin (mêmes que mobile et PC). */
object OF {
    val Background = Color(0xFF000000)
    val Surface = Color(0xFF121214)
    val SurfaceRaised = Color(0xFF1C1C1E)
    val SurfaceHigh = Color(0xFF2A2A2E)
    val Stroke = Color(0x24FFFFFF)
    val Accent = Color(0xFF4DA3FF)
    val TextPrimary = Color(0xFFF5F5F7)
    val TextSecondary = Color(0xFFB4B4BC)
    val TextTertiary = Color(0xFF7C7C86)
    val Danger = Color(0xFFFF453A)
    val Success = Color(0xFF32D74B)

    /** Marges de sécurité des téléviseurs (5 % de l'image peut être rogné). */
    val SafeX = 48.dp
    val SafeY = 27.dp
    val Gutter = 48.dp
}

private val scheme: ColorScheme = darkColorScheme(
    primary = OF.Accent,
    onPrimary = Color.Black,
    secondary = OF.Accent,
    background = OF.Background,
    onBackground = OF.TextPrimary,
    surface = OF.Surface,
    onSurface = OF.TextPrimary,
    surfaceVariant = OF.SurfaceRaised,
    onSurfaceVariant = OF.TextSecondary,
    inverseSurface = OF.TextPrimary,
    inverseOnSurface = Color.Black,
    border = OF.Stroke,
    error = OF.Danger,
)

/** Typographie lisible à trois mètres. */
private val typography = Typography(
    displayLarge = TextStyle(fontSize = 52.sp, fontWeight = FontWeight.Bold, letterSpacing = (-1).sp),
    displayMedium = TextStyle(fontSize = 42.sp, fontWeight = FontWeight.Bold, letterSpacing = (-0.5).sp),
    displaySmall = TextStyle(fontSize = 34.sp, fontWeight = FontWeight.Bold),
    headlineLarge = TextStyle(fontSize = 30.sp, fontWeight = FontWeight.SemiBold),
    headlineMedium = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.SemiBold),
    headlineSmall = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.SemiBold),
    titleLarge = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.SemiBold),
    titleMedium = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
    titleSmall = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Medium),
    bodyLarge = TextStyle(fontSize = 18.sp, lineHeight = 26.sp),
    bodyMedium = TextStyle(fontSize = 16.sp, lineHeight = 23.sp),
    bodySmall = TextStyle(fontSize = 14.sp, lineHeight = 20.sp),
    labelLarge = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.SemiBold),
    labelMedium = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium),
    labelSmall = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium),
)

/**
 * Défilement « pivot » des listes verticales (comme Google TV) : l'élément focalisé se place
 * toujours au même endroit de l'écran (haut à [fraction] de la hauteur) ; en haut de page, la
 * liste revient à son début (bornée par le défilement).
 */
@OptIn(ExperimentalFoundationApi::class)
class PivotSpec(private val fraction: Float, private val minOffsetPx: Float = 0f) : BringIntoViewSpec {
    override fun calculateScrollDistance(offset: Float, size: Float, containerSize: Float): Float {
        val target = maxOf(containerSize * fraction, minOffsetPx)
        // Élément plus grand que l'espace restant (carrousel) : aligné en haut.
        if (size >= containerSize - target) return offset
        return offset - target
    }
}

val LocalAccent = staticCompositionLocalOf { OF.Accent }

@Composable
fun OptiFinTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = scheme, typography = typography) {
        CompositionLocalProvider(LocalAccent provides OF.Accent, content = content)
    }
}
