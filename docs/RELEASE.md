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

Dort liegen ausschließlich **Arbeitskopien** der Dokumenterzeugung — je Vorgang
ein Ordner unter `Generated\Arbeit\`, gelöscht, sobald das Schreiben in der Akte
abgelegt ist. Ein Update oder eine Deinstallation nimmt also nichts mit, was der
Anwalt noch braucht: die fertigen Schreiben liegen in seinem Aktenstammordner.

### Vorlagen

Die Vorlagen gehören dem Anwender und liegen in
`%APPDATA%\AutomationService\Vorlagen`. Was das Paket mitbringt
(`AutomationService/Templates/`), ist nur **Saatgut**: `VorlagenSeedService`
kopiert beim Start, was im Vorlagenordner fehlt, und überschreibt dabei nie.

Läge es andersherum, überschriebe jedes Update seine angepassten Briefköpfe und
Formulierungen — lautlos, auffallen würde es erst an einem verschickten
Schreiben.

> Alles, was in `AutomationService/Templates/` liegt, sieht der Anwalt später in
> seiner Vorlagenauswahl. Dort gehören keine Testdateien hin — und **keine echten
> Kanzleivorlagen**.

Das Saatgut sind deshalb die neutralen `Muster_*.docx` ohne Kanzleibezug; die
`.gitignore` lässt nur diese durch. Bis August 2026 lagen hier stattdessen die
parametrisierten Fassungen der echten Anspruchsschreiben, und damit lagen
Briefkopf, Steuernummer und Bankverbindung der Kanzlei in einem öffentlichen
Repository und in jedem veröffentlichten Setup.

Der Fehlschluss dahinter ist lehrreich: parametrisiert wurde der **Fließtext**,
also die Mandantendaten. Kopf- und Fußzeile hat das Werkzeug nie angefasst, und
der Schriftsatz selbst — die eigentliche Arbeit der Kanzlei — blieb ohnehin
Wort für Wort erhalten. „Enthält nur noch `{{Platzhalter}}“ stimmte für den
Briefinhalt und war für die Datei trotzdem falsch.

Seine echten Vorlagen kommen deshalb auf anderem Weg auf den Rechner: einmal in
`%APPDATA%\AutomationService\Vorlagen` legen (dorthin schreibt auch der
`TemplateParametrizer`), und die Sicherung nimmt sie von da an mit.

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

**In der Anwendung steht sie unten in der Seitenleiste** (`VersionBadge`) und im
Einstellungen-Reiter „Über" (`UeberSettingsView`) — die Seitenleiste startet
eingeklappt, und ein Anwender sucht so etwas in den Einstellungen.

Beide zeigen `Version 1.0.0`, ausgeschrieben und ohne Entwicklerkürzel; ein
Klick öffnet „Über diese Anwendung" mit dem ganzen Satz dazu („Sie verwenden die
neueste Version."). Der Commit aus der `InformationalVersion` steht dort klein
als *Baustand für Rückfragen* — damit lässt sich eine Rückmeldung eindeutig
einem Build zuordnen, ohne die Nummer darüber zu verwässern.

Die Quelle ist `GET /health`, nicht die pubspec des Frontends. Beide Hälften
bekommen ihre Version aus demselben Tag, aber nur die des Dienstes prüft der
Rauchtest nach; und läuft ausnahmsweise ein fremder Dienst auf dem Port, fällt
das so auf, statt still zu bleiben.

### Tags sind unveränderlich

Ein Ruleset („Ausgelieferte Versionen", Ziel `refs/tags/v*`) verbietet Löschen
und Verschieben. Ohne das wäre die Versionsnummer keine Antwort mehr: ließe sich
`v1.0.0` nachträglich auf einen anderen Commit setzen, sagt „er hat 1.0.0"
nichts darüber aus, welchen Code er tatsächlich hat.

Neue Tags sind nicht betroffen — es gibt keine `creation`-Regel, ein Release
funktioniert wie beschrieben. Es gibt auch **keine Bypass-Actors**: bei Rulesets
sind Administratoren nicht automatisch ausgenommen, die Regel gilt also für
alle. Sitzt ein Tag doch einmal falsch, wird das Ruleset unter Settings → Rules
kurz auf `Disabled` gestellt.

### Probelauf ohne Veröffentlichung

`release.yml` lässt sich über `workflow_dispatch` mit einer Versionsnummer
starten. Dann läuft alles bis zum Installer, der als Artefakt hochgeladen wird —
der Release-Schritt wird übersprungen.

```powershell
gh workflow run release.yml -f version=0.0.1
gh run download <run-id>          # Installer holen
```

Ein Artefakt ist ein Prüfergebnis, **kein Auslieferungsweg**. Es hängt unter
*Actions* statt unter *Releases*, lässt sich auch bei einem öffentlichen
Repository nur angemeldet herunterladen, kommt zusätzlich in ein ZIP verpackt
und verfällt nach 90 Tagen. Wer den Weg testen will, den der Anwalt geht, setzt
einen echten Tag — auch eine `0.1.0` zur Probe, das Release lässt sich hinterher
löschen.

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

## So läuft ein Update

Für ihn ist es derselbe Vorgang wie die Erstinstallation — es gibt keinen
Update-Modus, keinen Deinstallieren-Schritt davor:

1. Du setzt einen neuen Tag, die CI baut, das Release erscheint.
2. Die Anwendung bemerkt es beim nächsten Start und zeigt „Update verfügbar".
3. Er klickt darauf, lädt die Setup-Datei und führt sie aus.
4. Fertig. Danach steht unten in der Seitenleiste die neue Nummer.

Dass das trägt, liegt an drei Entscheidungen weiter oben: die `AppId` bleibt über
alle Versionen gleich, also **ersetzt** der Installer die vorhandene Fassung,
statt eine zweite danebenzustellen. Läuft die Anwendung noch, erkennt Inno Setup
das und bittet, sie zu schließen. Und seine Daten liegen ohnehin nicht im
Programmordner, sondern unter `%APPDATA%\AutomationService` — Datenbank,
Vorlagen, Postfach-Zugang und Token-Cache überstehen das Update unberührt, weil
sie gar nicht erst angefasst werden.

Sein Vorlagenordner wird dabei **ergänzt, nicht überschrieben**: der
`VorlagenSeedService` legt nur an, was fehlt (siehe [Vorlagen](#vorlagen)). Neue
mitgelieferte Vorlagen kommen also hinzu, seine angepassten bleiben, wie sie
sind.

Steht mit dem Update eine Schemaänderung an, sichert der Dienst die Datenbank
vor der Migration von selbst nach `Sicherungen\` und bricht den Start ab, falls
das nicht gelingt. Ein Update kann seinen Datenbestand also nicht stillschweigend
beschädigen.

### Der Update-Hinweis

`AktualisierungsPruefer` (`lib/core/aktualisierung/`) fragt einmal je Sitzung
`api.github.com/repos/…/releases/latest` und vergleicht `tag_name` mit der
laufenden Version. Ist er höher, erscheint der Hinweis in der Seitenleiste und
im Reiter „Über"; der Knopf öffnet die Release-Seite im Browser.

Vier Entscheidungen dahinter:

- **Verglichen wird zahlenweise, nicht als Zeichenkette.** Sonst gälte `1.10.0`
  als älter als `1.9.0`, und die zehnte Auslieferung würde nie gemeldet.
- **Unlesbares gilt nie als Update.** Ein Tag, der nicht dem Schema entspricht,
  schickt den Anwalt sonst zu einem Download, den er längst hat.
- **Jeder Fehler bleibt stumm.** Ohne Netz, hinter einer Kanzlei-Firewall oder
  bei einem Ausfall von GitHub passiert schlicht nichts — kein Dialog, keine
  Verzögerung des Starts. Im Reiter „Über" steht dann allerdings ausdrücklich,
  dass *nicht geprüft werden konnte*, und nicht etwa „Sie sind aktuell": eine
  Prüfung, die nie stattgefunden hat, darf sich nicht als Entwarnung ausgeben.
- **Heruntergeladen und installiert wird nicht automatisch.** Nur der Installer
  schließt eine laufende Instanz sauber und lässt `%APPDATA%` unberührt.

Das setzt voraus, dass das Repository **öffentlich** bleibt. Wird es privat,
antwortet die API mit 404 und der Hinweis entfällt ersatzlos — die Anwendung
funktioniert weiter, du musst dann wieder selbst Bescheid geben.

> Die große Lösung wäre [Velopack](https://velopack.io) mit echtem Auto-Update,
> das im Hintergrund lädt und beim nächsten Start einspielt. Das ersetzt Inno
> Setup und ist eine eigene Umstellung; sie lohnt erst, wenn mehrere Rechner zu
> versorgen sind.

## Toolchain ist festgenagelt

`global.json` legt das .NET-SDK fest, `FLUTTER_VERSION` in beiden Workflows die
Flutter-Version.

Für die Flutter-Seite liegt daneben eine `.fvmrc` (in `Automation_App_Frontend/`):
Wer [FVM](https://fvm.app) benutzt, bekommt mit `fvm use` genau die gepinnte
Fassung, egal welches Flutter sonst im PATH steht. Prüfkette und Format-Hook
greifen von selbst zum projektlokalen SDK (`.fvm/flutter_sdk`), sobald es
existiert; `scripts/versionspruefung.ps1` prüft dann dessen Fassung und schlägt
an, wenn `.fvmrc` und `FLUTTER_VERSION` auseinanderlaufen. FVM ist Angebot,
nicht Pflicht — ohne `.fvm/` prüft und benutzt die Kette das Flutter aus dem
PATH, wie bisher.

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

### Die Sperrdatei gehört zum Pin

`pubspec.lock` ist Teil dieser Festlegung, und sie kann dem Pin widersprechen:
Flutter pinnt `meta`, `matcher` und `test_api` **exakt** (nicht mit Caret), und
Dependabot sieht diese Pins nicht — es löst mit dem reinen Dart-SDK auf und trägt
Fassungen ein, die es mit `FLUTTER_VERSION` nicht geben kann. `pub get` stuft sie
dann bei jedem Lauf still zurück, und die Sperrdatei beschreibt einen Stand, der
nie gelaufen ist.

Der Schritt **„Sperrdatei passt zur Toolchain"** in `ci.yml` und `check.ps1` macht
das sichtbar: nach `flutter pub get` darf sich die Datei nicht ändern. Tut sie es,
ist die aufgelöste Fassung die richtige und gehört in den Commit — nicht
zurückgeworfen.

## Offen

- **Code-Signing.** Ohne Zertifikat warnt SmartScreen bei jeder Installation.
  Für einen einzelnen bekannten Anwender verschmerzbar (~200–400 €/Jahr).
  Ohne Signatur hängt die SmartScreen-Reputation am Datei-Hash, jede Version
  fängt also wieder bei null an; mit Signatur hinge sie am Herausgeber und
  wüchse über Versionen hinweg.
- **Update über eine bestehende Installation** ist noch nie gelaufen. Erst das
  zeigt, ob `AppId`-Zuordnung, Instanzerkennung und Datenerhalt in der Praxis
  greifen.
