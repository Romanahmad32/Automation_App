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
;
; Dazu seit #196 das Update aus der App heraus: Der Dienst laedt dieses Setup,
; prueft es und startet es mit
;   /SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NEUSTART=1 /LOG="..."
; (InstallerAufruf.cs, nie /FORCECLOSEAPPLICATIONS). Dazu gehoeren hier:
; InitializeSetup im [Code] (eigener Setup-Mutex, Warten auf den Dienst), der
; zweite [Run]-Eintrag und "--nach-update" in beiden [Run]-Eintraegen
; (Gegenstueck: der Windows-Runner der App,
; Automation_App_Frontend/windows/runner/main.cpp). InstallerVertragTests
; (Dienst) haelt die Namen auf allen Seiten zusammen.

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
; Bewusst KEIN SetupMutex=, obwohl genau das gemeint ist: Inno prueft und legt
; den SetupMutex erst NACH dem Skript-InitializeSetup an (issrc,
; Setup.MainFunc.pas) -- also erst nach den bis zu 90 s, die InitializeSetup
; auf den Dienst wartet. Gerade in dieser Zeit muss er aber schon bestehen.
; Deshalb uebernimmt InitializeSetup das selbst, als Erstes (SetupLaeuftMutex
; im [Code]). Mit der Direktive daneben faende Inno danach den eigenen Mutex
; und braeche ab.

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
; Beide Eintraege starten die App mit "--nach-update": Das Setup lebt dann noch
; und haelt SetupLaeuftMutex. Ohne den Schalter hielte die App das fuer ein
; laufendes Update und beendete sich mit einem Hinweis (windows/runner/main.cpp).
;
; Interaktiv: das Haekchen „Automation App starten" auf der letzten Seite.
Filename: "{app}\{#MyAppExeName}"; Parameters: "--nach-update"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
; Still, aus der App gestartet (/NEUSTART=1): die App von selbst wieder starten.
; Der Eintrag oben hat skipifsilent — ohne diesen hier bliebe die App nach dem
; Update aus, und der Anwalt saehe nur, dass sie verschwunden ist. Ein stilles
; Setup ohne /NEUSTART=1 (Verteilung per Skript) startet nichts.
Filename: "{app}\{#MyAppExeName}"; Parameters: "--nach-update"; Flags: nowait skipifnotsilent; Check: NeustartGewuenscht

[Code]
const
  // Haelt der installierte Dienst vom Start bis zum Prozessende
  // (Features/Aktualisierung/Domain/Services/DienstLaeuftMarke.cs).
  DienstMutex = 'AutomationServiceLaeuft';
  // Haelt dieses Setup von InitializeSetup bis zum Prozessende (CreateMutex
  // gibt das Handle nie frei, Windows schliesst es mit dem Prozess). Zwei Leser:
  // ein zweites Setup, das sonst dieselben Dateien gegen dieses ersetzte, und
  // die App selbst (windows/runner/main.cpp), die sich dann nicht startet --
  // sonst uebernaehme sie einen sterbenden Dienst oder startete einen neuen,
  // der DienstMutex wieder hielte.
  SetupLaeuftMutex = 'AutomationAppSetupLaeuft';
  WarteGrenzeMs = 90000;
  WarteSchrittMs = 250;
  NachlaufMs = 1500;

function NeustartGewuenscht: Boolean;
begin
  Result := ExpandConstant('{param:NEUSTART|0}') = '1';
end;

// Laeuft schon ein Setup (etwa: Doppelklick auf die Setup-Datei, waehrend das
// Update aus der App laeuft)? Still endet dieses dann sofort -- der Dienst
// sieht das an der Anlauffrist (InstallerStart.cs) und bleibt an. Interaktiv
// darf der Anwender warten und es noch einmal versuchen. False: abbrechen.
function KeinAnderesSetup: Boolean;
begin
  Result := True;
  while CheckForMutexes(SetupLaeuftMutex) do
  begin
    if WizardSilent then
    begin
      Log('Es laeuft schon ein Setup; dieses endet, ohne etwas zu veraendern.');
      Result := False;
      Exit;
    end;

    if MsgBox('Die Automation App wird gerade schon installiert oder aktualisiert.' + #13#10#13#10 +
      'Bitte warten Sie, bis das fertig ist, und klicken Sie dann auf ' + #$201A + 'Wiederholen' + #$2018 + '.',
      mbInformation, MB_RETRYCANCEL or MB_SETFOREGROUND) = IDCANCEL then
    begin
      Log('Es laeuft schon ein Setup; dieses wurde abgebrochen.');
      Result := False;
      Exit;
    end;
  end;
end;

// Wartet hoechstens WarteGrenzeMs, bis der Dienst-Mutex weg ist. True, wenn
// der Dienst beendet ist -- dann noch NachlaufMs dazu: Das Handle schliesst
// Windows beim Prozessende, die Programmdateien gibt es im selben Zug frei,
// aber nicht garantiert vor dem Mutex.
function WarteAufDienstende: Boolean;
var
  Gewartet: Integer;
begin
  Gewartet := 0;
  while CheckForMutexes(DienstMutex) and (Gewartet < WarteGrenzeMs) do
  begin
    Sleep(WarteSchrittMs);
    Gewartet := Gewartet + WarteSchrittMs;
  end;

  Result := not CheckForMutexes(DienstMutex);
  if Result then
  begin
    Log(Format('Dienst nach %d ms beendet.', [Gewartet]));
    Sleep(NachlaufMs);
  end
  else
    Log(Format('Dienst nach %d ms noch nicht beendet.', [Gewartet]));
end;

// Wartet, bis der Dienst sich selbst beendet hat, bevor Inno Dateien ersetzt.
//
// Warum ueberhaupt: Beendet der Anwender die App, faehrt der Dienst geordnet
// herunter -- er schreibt die automatische Sicherung (ShutdownTimeout 60 s,
// Program.cs) und gibt seine verborgene Word-Instanz frei. Bis dahin sind die
// Dateien unter {app}\backend gesperrt. Liesse Inno den Restart Manager vorher
// ran, beendete der einen Dienst mitten in der Sicherung, und eine verwaiste
// WINWORD.EXE bliebe zurueck. Deshalb 90 s: die 60 s des Dienstes plus Reserve.
//
// Warum hier und nicht in PrepareToInstall, wo es zuerst stand: InitializeSetup
// laeuft vor jedem Fenster, also auch vor der Suche nach gesperrten Dateien
// (Restart Manager). PrepareToInstall laeuft erst mit offenem Setup-Fenster --
// eine Sleep-Schleife dort laesst es einfrieren ("Keine Rueckmeldung").
//
// Still (Update aus der App): warten. Laeuft die Zeit ab, geht es trotzdem
// weiter -- dann uebernimmt der Restart Manager (CloseApplications=yes) wie vor
// #196; ein Abbruch liesse den Anwalt ohne App und ohne Update zurueck.
// Interaktiv (Doppelklick auf die Setup-Datei): Die App ist meist noch offen,
// und der Dienst endet erst, wenn der Anwender sie schliesst. Das muss er
// lesen, sonst wartete er ratlos vor einem Setup, das sich nicht zeigt.
// "Abbrechen" beendet das Setup, bevor es etwas veraendert hat.
function InitializeSetup(): Boolean;
begin
  Result := KeinAnderesSetup;
  if not Result then
    Exit;

  // Ab hier gilt das Update als laufend -- auch waehrend des Wartens unten.
  CreateMutex(SetupLaeuftMutex);

  if not CheckForMutexes(DienstMutex) then
    Exit;

  if WizardSilent then
  begin
    if not WarteAufDienstende then
      Log('Der Restart Manager uebernimmt.');
    Exit;
  end;

  while CheckForMutexes(DienstMutex) do
  begin
    if MsgBox('Die Automation App ist noch ge' + #$00F6 + 'ffnet. Bitte schlie' + #$00DF + 'en Sie die App ' +
      'und klicken Sie dann auf ' + #$201A + 'Wiederholen' + #$2018 + '.' + #13#10#13#10 +
      'Nach dem Schlie' + #$00DF + 'en sichert die App noch kurz Ihre Daten ' + #$2013 +
      ' das kann bis zu einer Minute dauern.', mbInformation, MB_RETRYCANCEL or MB_SETFOREGROUND) = IDCANCEL then
    begin
      Log('Die App ist noch geoeffnet; das Setup wurde abgebrochen.');
      Result := False;
      Exit;
    end;

    // Ohne Fenster: Die Meldung ist zu, der Assistent noch nicht da.
    if not WarteAufDienstende then
      Log('Der Dienst laeuft noch; die Meldung erscheint erneut.');
  end;
end;
