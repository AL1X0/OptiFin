; Installateur Windows d'OptiFin (Inno Setup 6).
;
;   ISCC.exe /DAppVersion=1.0.34 windows\installer\optifin.iss
;   → build\windows\installer\OptiFin-windows-setup.exe
;
; Installation par utilisateur (aucun droit administrateur), en français. Lancé avec
; /VERYSILENT par la mise à jour automatique de l'appli : remplace la version installée,
; ferme l'appli si besoin puis la relance.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
; Identifiant fixe : chaque version remplace la précédente. NE PAS MODIFIER.
AppId={{2696BCA1-D7ED-49C0-8D5B-9DAC507F17F6}
AppName=OptiFin
AppVersion={#AppVersion}
AppVerName=OptiFin {#AppVersion}
AppPublisher=OptiFin
AppPublisherURL=https://github.com/AL1X0/OptiFin
AppUpdatesURL=https://github.com/AL1X0/OptiFin/releases/latest
DefaultDirName={localappdata}\Programs\OptiFin
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir=..\..\build\windows\installer
OutputBaseFilename=OptiFin-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\optifin.exe
UninstallDisplayName=OptiFin
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=force
RestartApplications=no

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Fichiers d'une ancienne version devenus inutiles (bibliothèques renommées ou retirées).
Type: filesandordirs; Name: "{app}\data"

[Icons]
Name: "{userprograms}\OptiFin"; Filename: "{app}\optifin.exe"
Name: "{userdesktop}\OptiFin"; Filename: "{app}\optifin.exe"; Tasks: desktopicon

[Run]
; Installation classique : case « Lancer OptiFin » à la fin.
Filename: "{app}\optifin.exe"; Description: "Lancer OptiFin"; Flags: nowait postinstall skipifsilent
; Mise à jour automatique (silencieuse) : l'appli est relancée d'elle-même.
Filename: "{app}\optifin.exe"; Flags: nowait; Check: WizardSilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
