// Ob von der Automation App noch etwas laeuft (#199) -- eingebunden in den
// [Code]-Abschnitt von setup.iss (#include), dort stehen auch die Konstanten
// (DienstMutex, AppExe, DienstExe, DeinstallationsSchluessel, die Wartezeiten).
// Eine eigene Datei, damit setup.iss kurz bleibt; uebersetzt wird beides
// zusammen (ISCC im Job "paket" der CI). Benutzt von InitializeSetup,
// DeinitializeSetup und InitializeUninstall.
//
// InstallerAbbruchVertragTests (Dienst) liest diese Datei mit.

// Der Ordner einer vorhandenen Installation, sonst ''. Aus der Registry statt
// {app}: In InitializeSetup steht {app} noch nicht fest, in DeinitializeSetup
// nach einem fruehen Abbruch womoeglich nie. HKA ist bei
// PrivilegesRequired=lowest HKCU -- so war es seit 1.0.0.
function InstallierterOrdner: String;
var
  Ordner: String;
begin
  Result := '';
  if RegQueryStringValue(HKA, DeinstallationsSchluessel, 'Inno Setup: App Path', Ordner) then
    Result := Ordner;
end;

// Laeuft DienstExe -- mit AuchFenster auch AppExe -- aus Ordner? 1.2.0 legt
// keinen Mutex an; ohne diesen Blick liefe das Setup weiter, waehrend die alte
// App noch offen ist oder ihr Dienst beim Beenden die Sicherung schreibt. Ueber
// den vollen Pfad, nicht nur den Namen: Eine Kopie anderswo (etwa die
// Entwicklungsfassung) hielte das Setup sonst grundlos auf. AnsiUpperCase,
// weil der Pfad den Benutzernamen enthaelt, und der darf Umlaute tragen.
//
// Jeder Fehler (WMI abgeschaltet, Zugriff verweigert) zaehlt als "laeuft
// nicht" und landet im Protokoll: Die Pruefung darf nie blockieren. Einen
// Haenger faengt das nicht ab -- WMI hat hier kein Zeitlimit, und ein
// stehender WMI-Dienst hielte das Setup an dieser Stelle an. Bewusst ohne
// Gegenmittel (das hiesse asynchrones WMI oder ein eigener Prozess); ein
// haengender WMI-Dienst ist selten und betrifft dann ohnehin mehr als dieses Setup.
function ProgrammLaeuft(const Ordner: String; const AuchFenster: Boolean): Boolean;
var
  Locator, Dienste, Prozesse, Prozess, Pfad: Variant;
  Praefix, PfadText, Abfrage: String;
  Anzahl, I: Integer;
begin
  Result := False;
  if Ordner = '' then
    Exit;

  Praefix := AnsiUpperCase(AddBackslash(Ordner));
  Abfrage := 'SELECT ExecutablePath FROM Win32_Process WHERE Name = ''' + DienstExe + '''';
  if AuchFenster then
    Abfrage := Abfrage + ' OR Name = ''' + AppExe + '''';
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Dienste := Locator.ConnectServer('', 'root\CIMV2', '', '');
    Prozesse := Dienste.ExecQuery(Abfrage);
    Anzahl := Prozesse.Count;
    I := 0;
    while (I < Anzahl) and (not Result) do
    begin
      Prozess := Prozesse.ItemIndex(I);
      Pfad := Prozess.ExecutablePath;
      // Leer, wenn dieser Prozess den Pfad nicht lesen darf.
      if not (VarIsNull(Pfad) or VarIsEmpty(Pfad)) then
      begin
        PfadText := Pfad;
        Result := (Pos(Praefix, AnsiUpperCase(PfadText)) = 1);
      end;
      I := I + 1;
    end;
  except
    Log('Ob die App noch laeuft, liess sich nicht pruefen: ' + GetExceptionMessage);
    Result := False;
  end;
end;

// Laeuft noch etwas von der App? Der Dienst -- Mutex (ab 1.3.0) oder DienstExe
// aus dem Installationsordner (auch 1.2.0) -- und, ausser mit NurDienst, ein
// Fenster (AppExe).
function AppLaeuft(const Ordner: String; const NurDienst: Boolean): Boolean;
begin
  Result := CheckForMutexes(DienstMutex);
  if not Result then
    Result := ProgrammLaeuft(Ordner, not NurDienst);
end;

// Wie WarteAufDienstende, aber auf alles, was AppLaeuft sieht: hoechstens
// GrenzeMs. True, wenn nichts mehr laeuft.
function WarteAufAppEnde(const Ordner: String; const GrenzeMs: Integer; const NurDienst: Boolean): Boolean;
var
  Gewartet: Integer;
begin
  Gewartet := 0;
  Result := not AppLaeuft(Ordner, NurDienst);
  while (not Result) and (Gewartet < GrenzeMs) do
  begin
    Sleep(ProzessSchrittMs);
    Gewartet := Gewartet + ProzessSchrittMs;
    Result := not AppLaeuft(Ordner, NurDienst);
  end;

  if Result then
  begin
    Log(Format('App nach %d ms beendet.', [Gewartet]));
    if Gewartet > 0 then
      Sleep(NachlaufMs);
  end
  else
    Log(Format('App nach %d ms noch nicht beendet.', [Gewartet]));
end;

// Fuer InitializeSetup und InitializeUninstall: True, wenn von der App nichts
// mehr laeuft. False beendet Setup bzw. Deinstallation, bevor sie etwas
// veraendert haben -- Inno stellt bei einem Abbruch mittendrin ersetzte
// Dateien nicht wieder her.
//
// Erst kurz warten: Wer die App gerade geschlossen hat, dessen Dienst sichert
// vielleicht nur noch. Still: hoechstens WarteGrenzeMs weiter, ohne Meldung --
// Inno unterdrueckt MsgBox im [Code] auch mit /SUPPRESSMSGBOXES nicht, und
// beim Update aus der App saehe niemand sie. Interaktiv: die Meldung mit
// "Wiederholen", so oft der Anwender will; "Abbrechen" beendet.
//
// NurDienst (das stille Setup): Gewartet wird nur auf den Dienst. Ein Fenster,
// das dann noch offen ist -- etwa eine zweite Instanz der App, die den Dienst
// nur mitbenutzt hat (BackendLauncher) und nach "Jetzt neu starten" nicht mit
// zugeht --, schliesst der Restart Manager wie vor #199: CloseApplications=yes
// (still ohne Rueckfrage), AppExe und die DLLs fallen unter die Vorgabe von
// CloseApplicationsFilter (*.exe,*.dll,*.chm). Er schickt WM_QUERYENDSESSION,
// WM_ENDSESSION und zuletzt WM_CLOSE; das schliesst ein Flutter-Fenster wie
// das X, und die App haelt ihr Ende nicht auf. Wieder gestartet wird es nicht
// (RestartApplications=no) -- das tut der [Run]-Eintrag. Die Deinstallation
// kennt keinen Restart Manager (issrc, Setup.Uninstall.pas) und wartet
// deshalb auch still auf beide.
function AppGeschlossen(const Ordner: String; const Still, NurDienst: Boolean): Boolean;
begin
  Result := not AppLaeuft(Ordner, NurDienst);
  if Result then
    Exit;

  Result := WarteAufAppEnde(Ordner, KurzWarteMs, NurDienst);
  if Result then
    Exit;

  if Still then
  begin
    Result := WarteAufAppEnde(Ordner, WarteGrenzeMs, NurDienst);
    if not Result then
      Log('Die App laeuft noch; es endet, ohne etwas zu veraendern.');
    Exit;
  end;

  repeat
    if MsgBox('Die Automation App ist noch ge' + #$00F6 + 'ffnet oder wird gerade beendet.' + #13#10#13#10 +
      'Bitte schlie' + #$00DF + 'en Sie die App und warten Sie etwa eine Minute, bis sie Ihre Daten ' +
      'gesichert hat. Klicken Sie dann auf ' + #$201A + 'Wiederholen' + #$2018 + '.',
      mbInformation, MB_RETRYCANCEL or MB_SETFOREGROUND) = IDCANCEL then
    begin
      Log('Die App laeuft noch; abgebrochen.');
      Result := False;
      Exit;
    end;

    Result := WarteAufAppEnde(Ordner, KurzWarteMs, NurDienst);
  until Result;
end;
