# Images de la fiche Store (Partner Center › Logos Windows Store), générées depuis l'icône 1024 px :
# affiche 9:16, image de zone 1:1, icônes 300 / 150 / 71.
#   powershell -File windows-native/store/make-listing.ps1
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile((Resolve-Path "$PSScriptRoot/../../assets/branding/icon_1024.png"))
$out = "$PSScriptRoot/listing"
New-Item -ItemType Directory -Force $out | Out-Null

function New-Image($name, $w, $h, $logo, $logoY, $title) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::Black)
  $g.DrawImage($src, [int](($w - $logo) / 2), [int]$logoY, [int]$logo, [int]$logo)
  if ($title) {
    $font = New-Object System.Drawing.Font('Segoe UI Semibold', [single]($w * 0.11), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF 0, ([single]($logoY + $logo * 0.92)), $w, ([single]($w * 0.2))
    $g.DrawString('OptiFin', $font, [System.Drawing.Brushes]::White, $rect, $fmt)
    $font.Dispose()
  }
  $bmp.Save("$out/$name.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}

New-Image 'affiche-1440x2160' 1440 2160 1100 420 $true
New-Image 'zone-2160x2160' 2160 2160 1500 220 $true
New-Image 'icone-300x300' 300 300 300 0 $false
New-Image 'icone-150x150' 150 150 150 0 $false
New-Image 'icone-71x71' 71 71 71 0 $false
$src.Dispose()
