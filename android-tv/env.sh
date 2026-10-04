# Environnement de compilation locale de l'appli TV (JDK, SDK Android, dossier temporaire court :
# Java y crée des sockets locales dont le chemin est limité en longueur).
B="$LOCALAPPDATA/OptiFin-build"
export JAVA_HOME="$B/jdk21"
export ANDROID_HOME="$B/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
mkdir -p /c/jt
export TMP='C:\jt' TEMP='C:\jt'
export JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:/jt -Djava.io.tmpdir=C:/jt"
[ -f local.properties ] || echo "sdk.dir=$(cygpath -m "$ANDROID_HOME")" > local.properties
