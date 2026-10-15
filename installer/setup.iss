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
;
; Seit #199: DeinitializeSetup startet die bisherige App wieder, wenn ein
; solches Update nach InitializeSetup scheitert, und Setup wie Deinstallation
; warten auch auf Programme aus dem Installationsordner, die keinen Mutex
; halten (1.2.0) -- still beim Setup nur auf den Dienst, Fenster schliesst
; dort der Restart Manager. Die Pruefung steht in AppLaeuft.iss (per #include
; im [Code]). Waechter: InstallerAbbruchVertragTests. Damit ein Abbruch immer
; den alten Dienst hinterlaesst (und so als Scheitern erkannt wird), ersetzt
; [Files] dessen Kern zuletzt -- davor Engine und AOT-Code der Oberflaeche
; direkt hintereinander, nach allem, was ein offenes Fenster sperren kann --,
; und "Abbrechen" ist waehrend der Installation aus
; (AllowCancelDuringInstall=no); Waechter: InstallerReihenfolgeVertragTests.

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
; gesperrten Dateien zu scheitern und einen Neustart zu verlangen. Still
; schliesst Inno sie ohne Rueckfrage -- darauf verlaesst sich das Update aus
; der App fuer jedes Fenster, das nach "Jetzt neu starten" noch offen ist
; (AppGeschlossen). Kein CloseApplicationsFilter: Die Vorgabe *.exe,*.dll,*.chm
; deckt automation_app.exe und die DLLs daneben. Nicht wieder starten: Das tut
; der [Run]-Eintrag, und zwar mit --nach-update.
CloseApplications=yes
RestartApplications=no
; Kein "Abbrechen", sobald Dateien ersetzt werden (wie /NOCANCEL): Ein
; verunsicherter Anwender soll das Update nicht mittendrin abbrechen -- Inno
; stellt ersetzte Dateien nicht wieder her (issrc, Setup.MainForm.pas: im
; Schritt ssInstall zaehlt "Abbrechen" nur mit AllowCancelDuringInstall).
; Vorher, im Assistenten eines Doppelklicks, bleibt Abbrechen moeglich.
AllowCancelDuringInstall=no
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
; Das gesamte Paket inklusive des Unterordners "backend" -- dort erwartet
; BackendLauncher den Dienst. Aufgeteilt nur der REIHENFOLGE wegen (#199):
; Inno ersetzt die Dateien in der Reihenfolge dieser Eintraege (issrc,
; Setup.Install.pas, CopyFiles), innerhalb eines Platzhalters sortiert nach
; Ordner, dann Name (Compiler.SetupCompiler.pas, SortFileList) -- als ein
; einziger Eintrag kaeme backend\AutomationService.dll schon frueh. Bricht ein
; stilles Update danach ab, startete DeinitializeSetup schon den neuen Dienst,
; der die Zielversion meldete: Die Merkdatei hielte das fuer Erfolg, und
; "Erneut versuchen" boete nichts mehr an. Deshalb kommt, woran der Dienst
; seine Version zeigt, ganz zuletzt; bis dahin startet nach einem Abbruch der
; alte Dienst, und das Scheitern wird erkannt (DeinitializeSetup).
; Die Menge der Dateien ist dieselbe wie mit einem Eintrag; jeder traegt
; ignoreversion, Platzhalter dazu recursesubdirs createallsubdirs, und jeder
; schreibt seine Dateien ins Deinstallationsprotokoll.
;
; 1. Der Dienst ohne seinen Kern (unten, Eintraege 5 und 6).
Source: "{#SourceDir}\backend\*"; DestDir: "{app}\backend"; Excludes: "\hostfxr.dll,\hostpolicy.dll,\coreclr.dll,\clrjit.dll,\System.Private.CoreLib.dll,\AutomationService.deps.json,\AutomationService.runtimeconfig.json,\AutomationService.dll"; Flags: ignoreversion recursesubdirs createallsubdirs
; 2. Die Daten der Oberflaeche (flutter_assets) ohne die beiden Dateien, die
;    zur Engine passen muessen.
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Excludes: "\icudtl.dat,\app.so"; Flags: ignoreversion recursesubdirs createallsubdirs
; 3. Der Wurzelordner ohne die Engine: automation_app.exe, die Plugin-DLLs,
;    die VC++-Laufzeit -- und was kuenftig neben backend und data liegt. Vor
;    Engine und AOT-Code, weil hier die wahrscheinlichste Sperre liegt: ein
;    Fenster, das der Restart Manager nicht schliessen konnte, haelt
;    automation_app.exe. Bricht das Setup daran ab, sind Engine und AOT-Code
;    noch beide alt und passen zusammen.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "\backend,\data,\flutter_windows.dll"; Flags: ignoreversion recursesubdirs createallsubdirs
; 4. Engine, ICU-Daten und AOT-Code direkt hintereinander -- sie passen nur
;    zusammen, wenn sie aus derselben Flutter-Fassung stammen. Die Engine
;    zuerst: Runner und Plugins aus Eintrag 3 sind dann schon neu und rufen sie
;    auf, je kuerzer sie neben der alten stehen, desto besser. Zwischen Engine
;    und AOT-Code liegt so nur icudtl.dat; welche Seite zuerst kommt, ist fuer
;    einen Abbruch genau dazwischen gleich.
Source: "{#SourceDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\data\icudtl.dat"; DestDir: "{app}\data"; Flags: ignoreversion
Source: "{#SourceDir}\data\app.so"; DestDir: "{app}\data"; Flags: ignoreversion
; 5. Die Laufzeit des Dienstes, die genau zusammenpassen muss (Host,
;    CoreCLR, JIT, CoreLib) -- beieinander statt ueber 300 Dateien verstreut.
Source: "{#SourceDir}\backend\hostfxr.dll"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "{#SourceDir}\backend\hostpolicy.dll"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "{#SourceDir}\backend\coreclr.dll"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "{#SourceDir}\backend\clrjit.dll"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "{#SourceDir}\backend\System.Private.CoreLib.dll"; DestDir: "{app}\backend"; Flags: ignoreversion
; 6. Zuletzt, woran der Dienst seine Version zeigt: Programmfassung.Aktuell
;    liest sie aus AutomationService.dll -- als allerletzte Datei. Davor ihre
;    Beschreibung (deps.json, runtimeconfig.json): Eine alte DLL mit neuer
;    Beschreibung laeuft eher als eine neue DLL mit alter.
Source: "{#SourceDir}\backend\AutomationService.deps.json"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "{#SourceDir}\backend\AutomationService.runtimeconfig.json"; DestDir: "{app}\backend"; Flags: ignoreversion
Source: "{#SourceDir}\backend\AutomationService.dll"; DestDir: "{app}\backend"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Beide Eintraege starten die App mit "--nach-update": Das Setup lebt dann noch
; und haelt SetupLaeuftMutex. Ohne den Schalter hielte die App das fuer ein
; laufendes Update und beendete sich mit einem Hinweis (windows/runner/main.cpp).
; Ebenso der Neustart nach einem gescheiterten Update (DeinitializeSetup).
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

  // Die beiden Programme der App: im Installationsordner und unter "backend"
  // (BackendLauncher im Frontend). Nach ihnen sucht ProgrammLaeuft.
  AppExe = '{#MyAppExeName}';
  DienstExe = 'AutomationService.exe';
  // Wie in beiden [Run]-Eintraegen, fuer den Neustart in DeinitializeSetup.
  NachUpdateSchalter = '--nach-update';
  // Hier vermerkt Inno den Installationsordner ("Inno Setup: App Path"): die
  // AppId aus [Setup], ohne die verdoppelte Klammer, plus "_is1".
  DeinstallationsSchluessel = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{2688470D-4684-412B-A385-A0B658CD2940}_is1';
  // Wie lange gewartet wird, bevor die Meldung erscheint, und nach
  // "Wiederholen" -- ohne Fenster, deshalb kurz.
  KurzWarteMs = 3000;
  // Ein Blick per WMI kostet mehr als einer auf den Mutex.
  ProzessSchrittMs = 1000;

var
  // Ab InitializeSetup, nach dem eigenen Mutex: Dieses Setup ist ein stilles
  // Update aus der App und hat wirklich begonnen (DeinitializeSetup).
  AppUpdateBegonnen: Boolean;
  // Erst in CurStepChanged(ssPostInstall) -- also nur nach einer vollstaendigen
  // Installation, wenn der [Run]-Eintrag die App schon gestartet hat.
  InstallationVollstaendig: Boolean;

function NeustartGewuenscht: Boolean;
begin
  Result := ExpandConstant('{param:NEUSTART|0}') = '1';
end;

// Das Update aus der App (InstallerAufruf.cs): still und mit /NEUSTART=1 --
// dieselbe Unterscheidung wie im zweiten [Run]-Eintrag (skipifnotsilent,
// Check: NeustartGewuenscht). Ein Doppelklick auf die Setup-Datei ist keins,
// ein stilles Setup ohne den Schalter (Verteilung per Skript) auch nicht.
function IstUpdateAusDerApp: Boolean;
begin
  Result := WizardSilent and NeustartGewuenscht;
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

// Ob von der App noch etwas laeuft, und das Warten darauf: InstallierterOrdner,
// ProgrammLaeuft, AppLaeuft, WarteAufAppEnde, AppGeschlossen. Hier, weil
// Pascal nur Bekanntes aufruft: nach den Konstanten, vor InitializeSetup.
#include "AppLaeuft.iss"

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
// Still (Update aus der App): nur auf den Dienst warten -- erst fein getaktet
// ueber seinen Mutex, dann per AppGeschlossen auf DienstExe aus dem
// Installationsordner (auch ohne Mutex), hoechstens noch einmal WarteGrenzeMs.
// Laeuft der Dienst dann immer noch, endet das Setup, bevor es etwas veraendert
// hat (#199): Den Dienst mitten in der Sicherung soll der Restart Manager
// nicht beenden, und scheitert er daran, bricht das Setup womoeglich erst
// mittendrin ab -- ersetzte Dateien stellt Inno nicht wieder her. Ein noch
// offenes Fenster (etwa eine zweite Instanz) schliesst dagegen wie vor #199
// der Restart Manager (CloseApplications=yes, siehe AppGeschlossen).
// Interaktiv (Doppelklick auf die Setup-Datei): Die App ist meist noch offen,
// und der Dienst endet erst, wenn der Anwender sie schliesst. Das muss er
// lesen, sonst wartete er ratlos vor einem Setup, das sich nicht zeigt --
// gewartet wird hier auf Dienst und Fenster (deckt 1.2.0 ohne Mutex ab).
// "Abbrechen" beendet das Setup, bevor es etwas veraendert hat.
function InitializeSetup(): Boolean;
begin
  Result := KeinAnderesSetup;
  if not Result then
    Exit;

  // Ab hier gilt das Update als laufend -- auch waehrend des Wartens unten.
  CreateMutex(SetupLaeuftMutex);
  // Erst jetzt: Endete dieses Setup oben, weil schon eines lief, startet
  // jenes die App. Ab hier ist es dieses (DeinitializeSetup).
  AppUpdateBegonnen := IstUpdateAusDerApp;

  if WizardSilent and CheckForMutexes(DienstMutex) then
  begin
    if not WarteAufDienstende then
      Log('Der Dienst laeuft noch.');
  end;

  // Still nur der Dienst (NurDienst), interaktiv Dienst und Fenster.
  Result := AppGeschlossen(InstallierterOrdner, WizardSilent, WizardSilent);
end;

// ssPostInstall kommt nur nach einer vollstaendigen Installation -- und erst
// nach den [Run]-Eintraegen ohne postinstall (issrc, Setup.MainForm.pas,
// TMainForm.Install): Die App laeuft dann schon wieder. Scheitert die
// Installation, kommt es nicht.
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    InstallationVollstaendig := True;
end;

// Ein stilles Update aus der App, das nach InitializeSetup scheiterte: Der
// Restart Manager konnte nicht schliessen, eine Datei war gesperrt (mit
// /SUPPRESSMSGBOXES gilt dann die Vorgabe, also Abbruch) -- oder
// InitializeSetup gab auf. "Abbrechen" im stillen Fortschrittsfenster geht
// nicht mehr, sobald Dateien ersetzt werden (AllowCancelDuringInstall=no).
// Dann startet kein [Run]-Eintrag die App, und der Anwalt saehe nur,
// dass sie verschwunden ist. Hier startet die bisherige wieder; die Merkdatei
// des Dienstes meldet beim Start "hat nicht geklappt" mit "Erneut versuchen".
//
// Was dann auf der Platte liegt: immer der alte Dienst-Kern -- Laufzeit und
// AutomationService.dll ersetzt [Files] erst ganz zuletzt --, davor womoeglich
// schon neue Teile des Dienstes und der Oberflaeche. Der Dienst meldet also
// die alte Version, die Merkdatei erkennt das Scheitern, und "Erneut
// versuchen" bietet die Zielversion wieder an. Haelt ein offenes Fenster
// automation_app.exe fest, scheitert das Setup im Wurzelordner, bevor Engine
// und AOT-Code ersetzt sind -- die Oberflaeche startet dann noch alt. Bleibt:
// ein Abbruch genau in den letzten Dateien (neue deps.json, alte DLL) und
// einer zwischen flutter_windows.dll und app.so, wenn die Flutter-Fassung
// wechselt -- dann startet die Oberflaeche womoeglich nicht, bis ein Setup
// durchlaeuft.
//
// Laeuft der Dienst noch, startet keine App: Einen Dienst, der noch
// herunterfaehrt, uebernaehme sie (BackendLauncher), oder ihr eigener liefe
// daneben auf derselben Datenbank. Ein Fenster zaehlt dagegen nicht: Still
// hat der Restart Manager die Fenster geschlossen, bevor er eine Datei
// ersetzte. Konnte er eines nicht schliessen, haengt es an einem Dienst, der
// fort ist, und ist nicht mehr zu gebrauchen -- die neu gestartete App bringt
// ihren eigenen mit. Ein solches Fenster als "laeuft" zu werten, liesse den
// Anwalt mit genau diesem toten Fenster zurueck.
//
// Mit --nach-update wie im [Run]-Eintrag: Dieses Setup haelt SetupLaeuftMutex,
// bis es endet. Ohne den Schalter hielte die App das fuer ein laufendes
// Update, zeigte ihren Hinweis und endete (windows/runner/main.cpp).
procedure DeinitializeSetup();
var
  Ordner, Programm: String;
  Fehler: Integer;
begin
  if not AppUpdateBegonnen then
    Exit;
  if InstallationVollstaendig then
    Exit;

  Ordner := InstallierterOrdner;
  Programm := AddBackslash(Ordner) + AppExe;
  if (Ordner = '') or (not FileExists(Programm)) then
  begin
    Log('Update nicht abgeschlossen; keine installierte App zum Neustart gefunden.');
    Exit;
  end;

  if AppLaeuft(Ordner, True) then
  begin
    Log('Update nicht abgeschlossen; der Dienst laeuft noch, die App startet nicht neu.');
    Exit;
  end;

  if Exec(Programm, NachUpdateSchalter, Ordner, SW_SHOWNORMAL, ewNoWait, Fehler) then
    Log('Update nicht abgeschlossen; die bisherige App startet wieder.')
  else
    Log('Update nicht abgeschlossen; die App liess sich nicht starten: ' + SysErrorMessage(Fehler));
end;

// Wie InitializeSetup: Eine laufende App haelt Dateien fest, die die
// Deinstallation entfernen will, und ihr Dienst schreibt womoeglich gerade
// die Sicherung. Still (Deinstallation per Skript) ohne Meldung, aber auch
// dann auf Dienst und Fenster: Die Deinstallation hat keinen Restart Manager,
// der ein Fenster schliessen koennte (issrc, Setup.Uninstall.pas).
function InitializeUninstall(): Boolean;
begin
  Result := AppGeschlossen(InstallierterOrdner, UninstallSilent, False);
end;
