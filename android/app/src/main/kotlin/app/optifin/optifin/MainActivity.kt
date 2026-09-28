package app.optifin.optifin

import android.content.res.Configuration
import app.optifin.optifin_native_player.OptifinNativePlayerPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Entrée / sortie du Picture-in-Picture : Flutter masque ou réaffiche les contrôles du lecteur.
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        OptifinNativePlayerPlugin.notifyPictureInPicture(isInPictureInPictureMode)
    }
}
