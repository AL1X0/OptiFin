package app.optifin.tv.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import app.optifin.tv.AppServices
import app.optifin.tv.ui.theme.OF
import kotlinx.coroutines.delay

/** Annonces courtes en bas à droite (soirée, mise à jour, erreurs), effacées après 4 s. */
@Composable
fun NoticeHost() {
    var text by remember { mutableStateOf<String?>(null) }
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        AppServices.notices.collect {
            text = it
            visible = true
        }
    }
    LaunchedEffect(text, visible) {
        if (visible) {
            delay(4000)
            visible = false
        }
    }
    Box(Modifier.fillMaxSize().padding(end = OF.SafeX, bottom = OF.SafeY + 8.dp), contentAlignment = Alignment.BottomEnd) {
        AnimatedVisibility(visible, enter = fadeIn() + slideInHorizontally { it / 3 }, exit = fadeOut() + slideOutHorizontally { it / 3 }) {
            Box(
                Modifier.widthIn(max = 520.dp).clip(RoundedCornerShape(16.dp)).background(Color(0xF21C1C20)).padding(horizontal = 22.dp, vertical = 14.dp),
            ) { Text(text ?: "", style = MaterialTheme.typography.bodyLarge, color = OF.TextPrimary) }
        }
    }
}
