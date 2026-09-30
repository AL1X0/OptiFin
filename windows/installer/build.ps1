# Construit OptiFin pour Windows et son installateur, sur ce PC.
#
#   powershell -File windows\installer\build.ps1 [-Version 1.0.40]
#   → build\windows\installer\OptiFin-windows-setup.exe
#
# Prérequis : Flutter, Visual Studio 2022 (C++ pour le bureau, avec ATL), Inno Setup 6.
param([string]$Version = "1.0.0")

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\..\.."
Set-Location $root

flutter build windows --release --build-name=$Version
if ($LASTEXITCODE -ne 0) { throw "Compilation Windows échouée" }

$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw "Inno Setup 6 introuvable (winget install JRSoftware.InnoSetup)" }

& $iscc /Q "/DAppVersion=$Version" "windows\installer\optifin.iss"
if ($LASTEXITCODE -ne 0) { throw "Création de l'installateur échouée" }
Get-Item "build\windows\installer\OptiFin-windows-setup.exe" | Select-Object FullName, Length
