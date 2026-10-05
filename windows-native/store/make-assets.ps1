# Génère les images du paquet Store (tuiles, logo, écran de démarrage) depuis l'icône 1024 px.
#   powershell -File windows-native/store/make-assets.ps1
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile((Resolve-Path "$PSScriptRoot/../../assets/branding/icon_1024.png"))
$out = "$PSScriptRoot/Assets"
# Nom, largeur, hauteur, taille du logo (proportion de la hauteur).
$specs = @(
  @('Square44x44Logo.scale-200', 88, 88, 1.0),
  @('Square44x44Logo.targetsize-256_altform-unplated', 256, 256, 1.0),
  @('Square44x44Logo.targetsize-48_altform-unplated', 48, 48, 1.0),
  @('Square44x44Logo.targetsize-24_altform-unplated', 24, 24, 1.0),
  @('Square150x150Logo.scale-200', 300, 300, 1.0),
  @('Wide310x150Logo.scale-200', 620, 300, 1.0),
  @('LargeTile.scale-200', 620, 620, 1.0),
  @('SmallTile.scale-200', 142, 142, 1.0),
  @('StoreLogo.scale-200', 100, 100, 1.0),
  @('SplashScreen.scale-200', 1240, 600, 0.8)
)
foreach ($s in $specs) {
  $bmp = New-Object System.Drawing.Bitmap $s[1], $s[2]
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Black)
  $size = [int]($s[2] * $s[3])
  $g.DrawImage($src, [int](($s[1] - $size) / 2), [int](($s[2] - $size) / 2), $size, $size)
  $bmp.Save("$out/$($s[0]).png", [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
$src.Dispose()
