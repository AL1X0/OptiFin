; Installateur Windows d'OptiFin (Inno Setup 6), appli native C# / WinUI 3.
;
;   dotnet publish src\OptiFin.App\OptiFin.App.csproj -c Release -r win-x64 -p:Platform=x64 -p:Version=1.0.N -o out\x64
;   ISCC.exe /DAppVersion=1.0.N installer\optifin.iss
;   → out\installer\OptiFin-windows-setup.exe
;
; Installation par utilisateur (aucun droit administrateur), en français. Lancé avec
; /VERYSILENT par la mise à jour automatique de l'appli : remplace la version installée,
; ferme l'appli si besoin puis la relance.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
; Identifiant fixe (le même que l'ancienne version Flutter, qu'il remplace). NE PAS MODIFIER.
AppId={{2696BCA1-D7ED-49C0-8D5B-9DAC507F17F6}
AppName=OptiFin
AppVersion={#AppVersion}
AppVerName=OptiFin {#AppVersion}
AppPublisher=OptiFin
AppPublisherURL=https://github.com/AL1X0/OptiFin
AppUpdatesURL=https://github.com/AL1X0/OptiFin/releases/latest
VersionInfoVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\OptiFin
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Windows 10 version 2004 au minimum (Windows App SDK).
MinVersion=10.0.19041
OutputDir=..\out\installer
OutputBaseFilename=OptiFin-windows-setup
SetupIconFile=..\src\OptiFin.App\Assets\OptiFin.ico
UninstallDisplayIcon={app}\OptiFin.exe
UninstallDisplayName=OptiFin
Compression=lzma2/ultra64
SolidCompression=yes
LZMANumBlockThreads=4
WizardStyle=modern
CloseApplications=force
RestartApplications=no

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[InstallDelete]
; Repart d'un dossier propre : fichiers d'une version précédente (dont l'ancienne appli Flutter).
; Les données de l'utilisateur (comptes, réglages, cache) sont ailleurs : %LOCALAPPDATA%\OptiFin.
Type: filesandordirs; Name: "{app}\*"

[Files]
; Symboles de débogage et métadonnées WinRT : inutiles à l'exécution (NativeAOT).
Source: "..\out\x64\*"; DestDir: "{app}"; Excludes: "*.pdb,*.winmd"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{userprograms}\OptiFin"; Filename: "{app}\OptiFin.exe"; AppUserModelID: "OptiFin.Windows"
Name: "{userdesktop}\OptiFin"; Filename: "{app}\OptiFin.exe"; Tasks: desktopicon

[Run]
; Installation classique : case « Lancer OptiFin » à la fin.
Filename: "{app}\OptiFin.exe"; Description: "Lancer OptiFin"; Flags: nowait postinstall skipifsilent
; Mise à jour automatique (silencieuse) : l'appli est relancée d'elle-même.
Filename: "{app}\OptiFin.exe"; Flags: nowait; Check: WizardSilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
