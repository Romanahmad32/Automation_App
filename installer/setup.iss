; Installer der Automation-App (Inno Setup 6.3+).
;
; Uebersetzt wird mit den Werten aus dem Release-Workflow:
;   iscc /DMyAppVersion=1.2.0 /DSourceDir=..\dist\Automation_App /DOutputDir=..\dist installer\setup.iss
;
; Zwei Entscheidungen, die hier bewusst so getroffen sind:
;
; 1. Installation je Benutzer (PrivilegesRequired=lowest), also nach
;    %LOCALAPPDATA%\Programs. Kein UAC-Dialog, keine Administratorrechte — und
;    vor allem: der Ordner ist fuer den Anwender SCHREIBBAR. Der Dienst legt
;    seine erzeugten Schreiben und den PDF-Cache unter "backend\Generated" ab.
;    Unter "C:\Programme" waere genau das nicht moeglich.
;
; 2. Die Nutzdaten liegen NICHT hier, sondern in
;    %APPDATA%\AutomationService (SQLite-Datenbank, Postfach-Konfiguration,
;    MSAL-Token-Cache). Weder Update noch Deinstallation fassen diesen Ordner
;    an: Inno entfernt nur, was es selbst installiert hat. Das ist Absicht —
;    das Mandantenregister eines Anwalts darf eine Deinstallation ueberleben.

#define MyAppName "Automation App"
#define MyAppExeName "automation_app.exe"
#define MyAppPublisher "Kanzlei"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\dist\Automation_App"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

[Setup]
; Feste Kennung: sie identifiziert das Produkt ueber alle Versionen hinweg.
; Wird sie geaendert, haelt Windows die neue Fassung fuer ein anderes Programm
; und installiert daneben statt darueber. Also niemals anfassen.
AppId={{2688470D-4684-412B-A385-A0B658CD2940}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=Automation_App_Setup_{#MyAppVersion}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName} {#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
; Beim Update eine laufende Instanz erkennen und schliessen lassen, statt an
; gesperrten Dateien zu scheitern und einen Neustart zu verlangen.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Das gesamte Paket inklusive des Unterordners "backend" — dort erwartet
; BackendLauncher den Dienst.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
