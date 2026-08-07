# Ausliefern und Aktualisieren

Wie aus einem Commit ein Programm auf dem Rechner des Anwalts wird — und was dabei
bewusst so entschieden wurde.

## Das Produkt ist eine Anwendung, nicht zwei

Der Anwalt klickt ein Symbol. Dass dahinter ein Flutter-Fenster und ein
ASP.NET-Dienst stecken, soll er nicht merken.

`AppBootstrap` (`Automation_App_Frontend/lib/core/backend/`) läuft vor der
eigentlichen Anwendung: es startet `backend\AutomationService.exe` als
Kindprozess, übergibt `--urls` und `--parent-pid`, und zeigt die Oberfläche erst,
wenn `GET /health` mit 200 antwortet. Solange läuft ein Warte-Bildschirm,
schlägt der Start fehl, ein Fehler-Bildschirm mit „Erneut versuchen".

Antwortet auf dem Port schon ein Dienst, wird dieser verwendet und keiner
gestartet. Das ist beim Entwickeln der Normalfall (`dotnet run` im einen
Terminal, `flutter run` im anderen) und verhindert zwei Instanzen auf derselben
Datenbank.

**Beendet wird der Dienst von sich aus.** `ParentProcessWatchdog` beobachtet die
übergebene Prozess-ID und ruft `StopApplication()`, sobald die Anwendung
verschwindet. Zwei Gründe für diese Richtung statt eines Abschusses durch das
Frontend: es greift auch, wenn die Oberfläche abstürzt, und es ist ein
*geordnetes* Herunterfahren — nur dabei gibt die PDF-Konvertierung ihre
Word-COM-Instanz frei. Ein `TerminateProcess` ließe `WINWORD.EXE` verwaist
zurück.

Host und Port stehen an genau zwei Stellen: `BackendEndpoint` im Frontend und
`"Urls"` in `appsettings.json`. **Nicht** in `launchSettings.json` — die gilt nur
für `dotnet run`, eine veröffentlichte Exe würde sonst stillschweigend auf Port
5000 lauschen.

## Was wo liegt

| Ort | Inhalt | Update | Deinstallation |
|---|---|---|---|
| `%LOCALAPPDATA%\Programs\Automation App` | Programm, `backend\`, mitgelieferte Vorlagen | wird ersetzt | wird entfernt |
| `%APPDATA%\AutomationService` | `automation.db`, `Vorlagen\`, `mailbox_config.json`, MSAL-Token-Cache, `Sicherungen\` | **unberührt** | **unberührt** |

Diese Trennung ist der Kern: alles, was dem Anwalt gehört, liegt außerhalb des
Installationsverzeichnisses. Deshalb installiert das Setup **je Benutzer**
(`PrivilegesRequired=lowest`) — kein UAC, keine Adminrechte, und der Ordner
bleibt schreibbar, was der Dienst für `backend\Generated` braucht.

### Vorlagen

Die Vorlagen gehören dem Anwender und liegen in
`%APPDATA%\AutomationService\Vorlagen`. Was das Paket mitbringt
(`AutomationService/Templates/`), ist nur **Saatgut**: `VorlagenSeedService`
kopiert beim Start, was im Vorlagenordner fehlt, und überschreibt dabei nie.

Läge es andersherum, überschriebe jedes Update seine angepassten Briefköpfe und
Formulierungen — lautlos, auffallen würde es erst an einem verschickten
Schreiben.

> Alles, was in `AutomationService/Templates/` liegt, sieht der Anwalt später in
> seiner Vorlagenauswahl. Dort gehören keine Testdateien hin.

### Sicherung

Eine Sicherung ist ein ZIP aus `automation.db` **und** `Vorlagen/*.docx`
(`SicherungsArchiv`). Die Vorlagen müssen mit, weil die Datenbank zu jeder
Formularvorlage *absolute* Pfade auf `.docx`-Dateien speichert — eine
Wiederherstellung auf einem neuen Rechner ergäbe sonst Vorlagenverweise ins
Leere. Ältere Sicherungen (blanke `.db`) bleiben einspielbar; das Format wird am
Dateiinhalt erkannt, nicht an der Endung, weil Anwender Dateien umbenennen.

Stehen beim Start Datenbank-Migrationen an, sichert `DatabaseMigrationService`
vorher automatisch nach `%APPDATA%\AutomationService\Sicherungen\` (die fünf
jüngsten bleiben). Scheitert die Sicherung, **bricht der Start ab** statt
ungesichert zu migrieren: eine misslungene Schemaänderung über dem
Mandantenregister ist nicht mehr rückgängig zu machen.

## Ein Release bauen

```powershell
git tag v1.0.0
git push origin v1.0.0
```

Das ist alles. `.github/workflows/release.yml` läuft rund zehn Minuten und hängt
`Automation_App_Setup_1.0.0.exe` (~85 MB) an ein GitHub-Release, mit dem Text aus
`installer/RELEASE_NOTES.md` (`{VERSION}` wird ersetzt).

Der Weg dorthin: Backend-Tests → Frontend-Tests → `scripts/build-package.ps1` →
`scripts/smoke-test.ps1` → Inno Setup → Artefakt → Release.

**Releases hängen an Tags, nicht an einem Release-Branch.** Ein zweiter
Dauerbranch hätte nur einen Zweck: eine alte Version pflegen, während `master`
weiterläuft. Bei einem einzigen Anwender, der immer die neueste Fassung bekommt,
tritt der Fall nicht ein. Wird doch einmal ein Hotfix auf einer alten Version
nötig, schneidet man `release/1.2` in diesem Moment vom Tag.

**Der Tag ist die einzige Quelle der Versionsnummer.** Sie geht in den
Flutter-Build (`--build-name`), in die Assembly (`-p:Version`) und in den
Installer. Von Hand wird nichts hochgezählt. Der Rauchtest prüft über `/health`
nach, dass sie wirklich in der Assembly angekommen ist.

Erste Stelle bei großen Umbauten, zweite bei neuen Funktionen, dritte bei
Fehlerbehebungen. Wichtig ist nur, dass sie steigt — sie steht in „Apps &
Features" und im Health-Endpunkt und ist die Antwort auf „welchen Stand hat er
eigentlich?".

### Probelauf ohne Veröffentlichung

`release.yml` lässt sich über `workflow_dispatch` mit einer Versionsnummer
starten. Dann läuft alles bis zum Installer, der als Artefakt hochgeladen wird —
der Release-Schritt wird übersprungen.

```powershell
gh workflow run release.yml -f version=0.0.1
gh run download <run-id>          # Installer holen
```

### Lokal bauen

```powershell
./scripts/build-package.ps1 -Version 1.2.0 -BuildNumber 1
./scripts/smoke-test.ps1 -PackageDirectory dist/Automation_App -ExpectedVersion 1.2.0
```

Dieselben Skripte laufen im `paket`-Job der CI bei jedem PR. Was dort grün ist,
ist das, was ausgeliefert wird — und dieser Job prüft eine Fehlerklasse, die
`dotnet test` und `flutter test` prinzipiell nicht sehen: ob aus dem Quellcode
ein *startfähiges Produkt* wird.

## Ausliefern

**Beim ersten Mal:** Release-Link schicken oder die Setup-Datei auf einem Stick
mitbringen. Er führt sie aus, klickt bei der SmartScreen-Warnung auf „Weitere
Informationen → Trotzdem ausführen", und hat danach ein Symbol auf dem Desktop.
Kein Terminal, keine Adminrechte, keine .NET-Installation.

Ist das Repository öffentlich, ist auch der Release-Link öffentlich. Soll das
nicht sein, muss das Repository privat werden — dann braucht er zum
Herunterladen einen GitHub-Zugang, und ein Stick oder Cloud-Ordner ist der
einfachere Weg.

**Was er selbst braucht:** Windows 10/11 (64 Bit), Microsoft Word (PDF-Vorschau),
Edge oder Chrome (Zentralruf). Einmalig die Postfach-Einrichtung in den
Einstellungen; die Azure-App-Registrierung für Outlook-Postfächer bleibt
Entwickleraufgabe (`docs/OUTLOOK_SETUP.md`).

**Updates:** identisch — neuer Tag, neuer Link. Der Installer installiert sich
über die vorhandene Version (gleiche `AppId`), erkennt eine laufende Instanz und
bittet, sie zu schließen.

> Er erfährt von sich aus **nichts** von einem Update; du musst ihm den Link
> schicken. Wenn das lästig wird: kleine Lösung ein Hinweis in der App gegen die
> GitHub-Releases-API, große Lösung [Velopack](https://velopack.io) mit echtem
> Auto-Update. Beides lohnt erst, wenn der manuelle Weg ein paarmal gelaufen ist.

## Toolchain ist festgenagelt

`global.json` legt das .NET-SDK fest, `FLUTTER_VERSION` in beiden Workflows die
Flutter-Version.

Der Grund steht in der Historie: die CI war ab dem 01.08.2026 eine Woche lang rot,
ohne dass jemand Code angefasst hätte. Beide Jobs zogen mit `channel: stable` und
`10.0.x` bei jedem Lauf das Neueste, während der Entwicklerrechner drei
Minor-Versionen zurücklag. In einem Projekt mit `TreatWarningsAsErrors`,
`AnalysisLevel=latest` und einem `flutter analyze`, das schon bei Info-Meldungen
mit Exit-Code 1 endet, genügt dafür eine einzige neue Analyzer-Regel. Der Bruch
kam nicht aus dem Repository, sondern aus dem Kalender.

Für eine Anwendung, deren Release die CI baut, ist das doppelt schlecht:
derselbe Commit könnte an zwei Tagen zwei verschiedene Pakete ergeben.

**Ein Versionssprung ist deshalb eine bewusste Entscheidung mit eigenem Commit** —
zusammen mit den Anpassungen, die er auslöst. Nicht etwas, das einem morgens die
CI zerlegt.

## Offen

- **Code-Signing.** Ohne Zertifikat warnt SmartScreen bei jeder Installation.
  Für einen einzelnen bekannten Anwender verschmerzbar (~200–400 €/Jahr).
- **Update-Benachrichtigung.** Siehe oben.
