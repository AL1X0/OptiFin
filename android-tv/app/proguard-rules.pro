# Règles R8 de l'appli TV (-PtvMinify=true). Les bibliothèques (Media3, OkHttp, Coil, kotlinx.serialization,
# Compose) apportent les leurs ; restent le code appelé par nom depuis du natif ou par réflexion.

# libmpv : méthodes et classes appelées depuis le JNI.
-keep class dev.jdtech.mpv.** { *; }
-keep class is.xyz.mpv.** { *; }

# Décodeur FFmpeg : Media3 le charge par réflexion, le natif rappelle ses méthodes.
-keep class androidx.media3.decoder.ffmpeg.** { *; }

# Traces lisibles dans les journaux de l'appli.
-keepattributes SourceFile,LineNumberTable
