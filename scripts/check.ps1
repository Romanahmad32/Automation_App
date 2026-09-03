<#
.SYNOPSIS
    Faehrt die komplette Pruefkette des Repos — dieselben Schritte wie die CI.

.DESCRIPTION
    Frontend und Backend liegen in verschiedenen Verzeichnissen und brauchen
    zusammen ein Dutzend Befehle in einer bestimmten Reihenfolge. Wer einen
    davon vergisst, haelt seine Aenderung fuer fertig und laesst die CI die
    Arbeit machen — oder, schlimmer, merkt den Bruch erst beim Anwender: ein
    vergessener build_runner-Lauf bleibt in "flutter analyze" und
    "flutter test" unsichtbar und faellt erst zur Laufzeit auf.

    Das Skript bricht nicht beim ersten Fehler ab, sondern faehrt alle Schritte
    und fasst am Ende zusammen — mit der Dauer je Schritt, damit sichtbar
    bleibt, wo die Zeit hingeht.

    Gefahren wird nacheinander, mit Live-Ausgabe. Das ist gemessen und nicht
    aus Bequemlichkeit so: Frontend und Backend teilen keine Datei, gleichzeitig
    zu laufen bringt auf vier Kernen aber fast nichts (150,6 s im Mittel seriell
    gegen 142,6 s gleichzeitig, bei ueberlappender Streuung). Der Grund ist,
    dass `flutter test --concurrency=8` und `dotnet test` die Kerne schon jeder
    fuer sich auslasten — nebeneinander nehmen sie sich die Rechenzeit nur
    gegenseitig weg (Backend-Tests allein 37 s, gleichzeitig 106 bis 118 s).
    Wer mehr Kerne hat, holt sich den Gewinn mit -Gleichzeitig; dort kommt die
    Ausgabe je Seite gesammelt statt live, damit sich die Protokolle nicht
    ineinanderschieben. Verloren geht dabei nichts.

    Ausgenommen sind bewusst die langlaufenden Paket-Schritte (build-package.ps1
    und smoke-test.ps1). Die gehoeren in die CI und ins Release, nicht in die
    Schleife waehrend der Arbeit.

    Die Schalter spannen zwei Achsen auf, die sich kombinieren lassen:

        WO    -NurFrontend / -NurBackend   welcher Teilbaum
        TIEFE -Regeln                      nur die Regeln, nicht das Verhalten

    Sie sind unabhaengig voneinander. `-NurFrontend` ist ausdruecklich *nicht*
    die schnelle Stufe — er faehrt alle Frontend-Schritte samt Codegenerierung
    und voller Testsuite und kostet drei bis vier Minuten. Wer waehrend der
    Arbeit eine Rueckmeldung in unter einer Minute will, nimmt
    `-Regeln -NurFrontend`.

.PARAMETER Beheben
    Laesst die Formatierer vor ihrer jeweiligen Pruefung *schreibend* laufen.
    Die Formatierung ist der einzige Schritt der Kette, dessen Fehler das
    Werkzeug selbst beheben kann — und zugleich der, der am haeufigsten und am
    unverstaendlichsten faellt: eine Datei, die per Skript umgeschrieben wurde,
    verliert still ihre CRLF-Enden und liefert dann hunderte ENDOFLINE-Zeilen
    fuer eine einzige Aenderung. Ohne diesen Schalter wird daraus eine
    Raterunde, mit ihm ein Befehl.

.PARAMETER Gleichzeitig
    Frontend und Backend nebeneinander, Ausgabe je Seite gesammelt. Lohnt erst
    ab deutlich mehr als vier Kernen (siehe oben).

.PARAMETER Regeln
    Faehrt nur, was die **Regeln** prueft — die Tabelle "Diese Regeln sind
    ausfuehrbar" aus CLAUDE.md: Dateilaenge, private Typen, Benennung,
    Schichten, Namespace, HTTP-Vertrag, Doku, Anforderungsverweise,
    Formatierung. Dazu `flutter analyze`, denn Lints sind dieselbe Sorte Regel
    und der billigste Fehlerfaenger ueberhaupt.

    Weggelassen wird, was *Verhalten* prueft: die Codegenerierung (15 bis 105 s)
    samt der Pruefung ihres Stands, und die Fachtests beider Seiten. Der
    Backend-Build bleibt drin — er traegt EnforceCodeStyleInBuild und
    TreatWarningsAsErrors, ist also selbst Regeldurchsetzung, und die
    Architektur-Tests brauchen ihn ohnehin.

    Gedacht fuer die Schleife waehrend der Arbeit, nicht als Tor vor dem PR:
    Was hier gruen ist, kann in den Fachtests noch fallen.

.EXAMPLE
    ./scripts/check.ps1
    ./scripts/check.ps1 -Beheben
    ./scripts/check.ps1 -NurFrontend
    ./scripts/check.ps1 -Gleichzeitig
    ./scripts/check.ps1 -Regeln                  # Regeln beider Seiten
    ./scripts/check.ps1 -Regeln -NurFrontend     # nur die Dart-Regeln
#>
[CmdletBinding()]
param(
    [switch]$NurFrontend,
    [switch]$NurBackend,
    [switch]$Beheben,
    [switch]$Gleichzeitig,
    [switch]$Regeln
)

Set-StrictMode -Version Latest

# Allererster Schritt: Stimmen die Werkzeugfassungen? Eine abweichende
# Toolchain macht bis zu sechs Schritte rot, die wie Codefehler aussehen
# (Begruendung und Vergleichslogik in versionspruefung.ps1). Erst nach diesem
# Abbruch gilt: Jeder rote Schritt weiter unten ist ein echter Befund.
#
# Bei Erfolg liefert die Pruefung das bin-Verzeichnis des FVM-SDKs zurueck —
# der projektlokalen Junction oder, wenn die fehlt, der gepinnten Fassung im
# FVM-Cache (oder nichts, dann gilt der PATH). Die Frontend-Schritte fahren
# mit genau dem SDK, dessen Fassung eben geprueft wurde.
$sdkBin = & (Join-Path $PSScriptRoot 'versionspruefung.ps1') -NurFrontend:$NurFrontend -NurBackend:$NurBackend
if ($LASTEXITCODE -ne 0) { exit 1 }

$flutterBefehl = if ($sdkBin) { Join-Path $sdkBin 'flutter.bat' } else { 'flutter' }
$dartBefehl    = if ($sdkBin) { Join-Path $sdkBin 'dart.bat' }    else { 'dart' }

$wurzel   = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $wurzel 'Automation_App_Frontend'
$backend  = Join-Path $wurzel 'AutomationService/AutomationService'

# Die Vorgabe von `flutter test` ist Kerne/2 — auf einem Vierkerner also zwei.
# Die Testlaeufe sind aber nicht rechen-, sondern startlastig (je Datei eine
# eigene VM). Gemessen auf vier Kernen: 73 s bei der Vorgabe, 51 s bei acht;
# zwoelf brachte nichts mehr. Dieselbe Zahl steht in ci.yml.
$testNebenlaeufigkeit = '8'

$hinweise = New-Object System.Collections.ArrayList

# Git-Hooks verdrahten. `.githooks/` ist versioniert, `core.hooksPath` nicht —
# ein frischer Klon kennt den Ordner also, benutzt ihn aber nicht. Hier gesetzt
# statt in einer Anleitung, weil dieses Skript ohnehin jeder faehrt, der etwas
# beitraegt: Damit greift der Geheimnis-Waechter ab dem ersten Pruefdurchlauf
# und nicht erst, wenn jemand einen Satz in der README gelesen hat.
#
# Nur schreiben, wenn es abweicht: `git config` beruehrt sonst .git/config bei
# jedem Lauf. Zeigt der Pfad woandershin, hat das jemand mit Absicht getan —
# dann bleibt es stehen und wird nur gemeldet.
#
# Verglichen werden **aufgeloeste Pfade**, nicht die Zeichenketten (behoben am
# 03.09.2026). Git nimmt fuer core.hooksPath auch einen absoluten Pfad, und der
# zeigte hier auf genau dieses .githooks/ — der Vergleich gegen '.githooks' sah
# darin trotzdem eine Abweichung. Gemeldet wurde dann, der Geheimnis-Waechter
# laufe nicht, waehrend er lief und Funde anhielt. Eine Falschmeldung
# ausgerechnet an der Stelle, an der jede Meldung ernst genommen werden muss:
# Wer sie zweimal liest und nichts findet, liest sie beim dritten Mal nicht
# mehr.
$hooksPfad = (& git -C $wurzel config --local core.hooksPath 2>$null)
if ([string]::IsNullOrWhiteSpace($hooksPfad)) {
    & git -C $wurzel config --local core.hooksPath '.githooks' 2>&1 | Out-Null
    $null = $hinweise.Add(
        'core.hooksPath auf .githooks/ gesetzt — der Geheimnis-Waechter laeuft ' +
        'ab jetzt vor jedem Commit (docs/RELEASE.md).')
}
else {
    $eingetragen = $hooksPfad.Trim()
    $gemeint = [System.IO.Path]::GetFullPath((Join-Path $wurzel '.githooks'))
    $tatsaechlich = if ([System.IO.Path]::IsPathRooted($eingetragen)) {
        [System.IO.Path]::GetFullPath($eingetragen)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $wurzel $eingetragen))
    }
    # Trennzeichen ueber ihren Kodepunkt, nicht als Literal: Ein
    # Backslash in einfachen Anfuehrungszeichen ist zu leicht zu
    # verlieren, und genau das ist beim Schreiben dieser Zeile passiert.
    $abschluss = [char[]]@(92, 47)
    if ($tatsaechlich.TrimEnd($abschluss) -ne $gemeint.TrimEnd($abschluss)) {
        $null = $hinweise.Add(
            "core.hooksPath zeigt auf '$eingetragen' statt auf .githooks/ — " +
            'der Geheimnis-Waechter vor dem Commit laeuft damit nicht.')
    }
}

# Laeuft die Anwendung, haelt ihr Kindprozess AutomationService.exe *und*
# .dll in bin\<Konfiguration>\net10.0\ offen. Jeder Build bricht dann mit
# MSB3021 ab — ein Fehler, der wie ein Uebersetzungsfehler aussieht und keiner
# ist. Statt den Anwender aus seiner Sitzung zu werfen, bauen wir in ein
# Ausweichverzeichnis.
#
# Das muss *innerhalb* des Projektbaums liegen: die Architektur- und
# Vertragstests suchen ihre Projektwurzel oberhalb der Test-DLL am Ordner mit
# AutomationService.csproj. Aus %TEMP% heraus faenden sie sie nicht und
# schluegen samt und sonders fehl — das saehe nach echtem Regelverstoss aus.
$binPruef     = Join-Path $backend 'bin-pruef'
$dienstLaeuft = @(Get-Process -Name 'AutomationService' -ErrorAction SilentlyContinue).Count -gt 0
$bauArgumente = @()

if ($dienstLaeuft -and -not $NurFrontend) {
    # Schraegstrich, nicht umgekehrter: MSBuild braucht den Abschluss, aber ein
    # `\` ganz am Ende steht in einem Argument, das PowerShell quoten muss,
    # direkt vor dem schliessenden Anfuehrungszeichen. Die Befehlszeilen-
    # zerlegung liest die beiden dann als maskiertes Anfuehrungszeichen und
    # zieht das naechste Argument mit in den Wert. Sichtbar wird das erst, wenn
    # der Klonpfad ein Leerzeichen enthaelt -- vorher quotet PowerShell nicht.
    $bauArgumente = @("-p:BaseOutputPath=$binPruef/")
    $null = $hinweise.Add(
        'Die Anwendung laeuft und sperrt bin\. Das Backend wurde nach ' +
        'bin-pruef\ gebaut; das Verzeichnis ist danach wieder geloescht.')
}

function New-Schritt {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Verzeichnis,
        [Parameter(Mandatory = $true)][string]$Datei,
        [Parameter(Mandatory = $true)][string[]]$Argumente,
        # Was zu tun ist, wenn der Schritt faellt. Erscheint in der Zusammenfassung.
        [string]$Hilfe = ''
    )
    [pscustomobject]@{
        Name        = $Name
        Verzeichnis = $Verzeichnis
        Datei       = $Datei
        Argumente   = $Argumente
        Hilfe       = $Hilfe
    }
}

# Ein Lauf einer Seite. Laeuft entweder hier (seriell, $live) oder in einem
# Hintergrundauftrag (gleichzeitig, gesammelte Ausgabe) — deshalb steht er als
# Skriptblock da und greift auf nichts von aussen zu.
#
# Die Ergebnisse nehmen zwei verschiedene Wege zurueck, und das ist der Kern
# des Ganzen: Im Live-Lauf muss der Rueckgabestrom frei bleiben. Faengt der
# Aufrufer ihn ab (`$lauf = & $seiteFahren ...`), faengt er die Werkzeugausgabe
# gleich mit — sie steht dann im Ergebnis statt auf dem Schirm, und PowerShell
# gibt den Kindprozessen erst gar keine Konsole mehr, weil es ihre Ausgabe ja
# selbst einsammelt. Der Live-Lauf schuettet seine Ergebnisse deshalb in die
# mitgegebene $senke und gibt selbst nichts zurueck. Nur der Hintergrund-
# auftrag, der ohnehin ueber die Serialisierung geht und keine Konsole hat,
# liefert ein Objekt.
$seiteFahren = {
    param($schritte, $live, $senke)

    Set-StrictMode -Version Latest
    $ergebnisse = @()
    $zeilen = New-Object System.Collections.Generic.List[string]

    # Entweder auf die Konsole oder ins Protokoll, nie beides: das gesammelte
    # Protokoll liest ausschliesslich der gleichzeitige Lauf, der es am Stueck
    # ausgibt. Im Live-Lauf steht schon alles auf dem Schirm — es daneben noch
    # zu sammeln hiesse, die zehntausenden Zeilen aus Tests und Builds ein
    # zweites Mal im Speicher zu halten und am Ende wegzuwerfen.
    function Schreibe($text, $live, $zeilen, $farbe) {
        if ($live) {
            if ($farbe) { Write-Host $text -ForegroundColor $farbe } else { Write-Host $text }
        }
        else {
            $zeilen.Add($text)
        }
    }

    foreach ($s in $schritte) {
        Schreibe '' $live $zeilen $null
        Schreibe "---- $($s.Name)" $live $zeilen 'Cyan'

        Push-Location $s.Verzeichnis
        $start = Get-Date
        try {
            [string[]]$argumente = $s.Argumente
            if ($live) {
                # Ohne Rohr und ohne Umleitung, damit die Werkzeuge ihre Konsole
                # behalten. flutter, dart und dotnet fragen, ob stdout ein
                # Terminal ist, und schalten sonst Farben, Fortschrittszeilen und
                # Rueckfragen ab. Am teuersten ist die Rueckfrage: build_runner
                # will wissen, ob es widersprechende Ausgaben loeschen darf, und
                # wartet auf die Antwort — hinter einem Rohr unsichtbar, der Lauf
                # sieht dann aus, als haenge er.
                & $s.Datei @argumente
            }
            else {
                # 2>&1, damit auch die Fehlerausgabe im gesammelten Protokoll
                # steht. Bewertet wird ausschliesslich $LASTEXITCODE — in Windows
                # PowerShell macht diese Umleitung aus jeder stderr-Zeile einen
                # ErrorRecord und setzt $? auf false, auch wenn das Werkzeug 0
                # zurueckgegeben hat.
                & $s.Datei @argumente 2>&1 | ForEach-Object {
                    Schreibe ([string]$_) $live $zeilen $null
                }
            }
            $code = $LASTEXITCODE
        }
        catch {
            Schreibe ([string]$_) $live $zeilen 'Red'
            $code = 1
        }
        finally {
            Pop-Location
        }

        $ergebnisse += [pscustomobject]@{
            Name     = $s.Name
            Ok       = ($code -eq 0)
            Hilfe    = $s.Hilfe
            Sekunden = [Math]::Round(((Get-Date) - $start).TotalSeconds, 1)
        }
    }

    if ($null -ne $senke) {
        foreach ($e in $ergebnisse) { $null = $senke.Add($e) }
    }
    else {
        [pscustomobject]@{
            Ergebnisse = $ergebnisse
            Ausgabe    = ($zeilen -join [Environment]::NewLine)
        }
    }
}

# ---------------------------------------------------------------------------
# Die Schritte
# ---------------------------------------------------------------------------

$frontendSchritte = @()
if (-not $NurBackend) {
    $frontendSchritte += New-Schritt 'Frontend: Abhaengigkeiten' $frontend $flutterBefehl @('pub', 'get')

    # Die Sperrdatei ist versioniert und muss zu der gepinnten Flutter-Fassung
    # passen. Aendert `pub get` sie, war der committete Stand mit dieser
    # Toolchain gar nicht erfuellbar (das Framework pinnt meta, matcher und
    # test_api exakt) — dann lief bisher immer etwas anderes, als dort stand.
    $frontendSchritte += New-Schritt 'Frontend: Sperrdatei passt zur Toolchain' $wurzel 'git' `
        @('diff', '--exit-code', '--', 'Automation_App_Frontend/pubspec.lock') `
        -Hilfe 'pub get hat pubspec.lock geaendert: die aufgeloeste Fassung mitcommitten, nicht zurueckwerfen.'

    # Der teuerste Schritt der Kette und einer, der Verhalten herstellt statt
    # Regeln zu pruefen — unter -Regeln faellt er weg, und mit ihm die Pruefung
    # seines Ergebnisses weiter unten.
    if (-not $Regeln) {
        $frontendSchritte += New-Schritt 'Frontend: Codegenerierung' $frontend $dartBefehl `
            @('run', 'build_runner', 'build') `
            -Hilfe 'Fehler in einer Annotation oder in build.yaml — nicht in den generierten Dateien selbst.'
    }

    # Vor der Pruefung des generierten Stands, nicht danach: `dart format lib`
    # schreibt auch injection.config.dart und app_router.gr.dart. Liefe es
    # spaeter, veraenderte es die beiden hinter dem Ruecken ihrer eigenen
    # Pruefung — der Lauf meldete alles gruen, die umformatierte Datei ginge mit
    # in den Commit, und erst die CI (die neu generiert und dann diffed) faende
    # den Bruch. So faellt stattdessen hier der Schritt darunter auf, was
    # genau richtig ist: dann ist die Codegenerierung nicht dart-format-rein.
    if ($Beheben) {
        $frontendSchritte += New-Schritt 'Frontend: Formatierung beheben' $frontend $dartBefehl @('format', 'lib', 'test')
    }

    # Die generierten Dateien sind versioniert. Weichen sie nach dem Lauf ab,
    # war der committete Stand veraltet: die Anwendung uebersetzt weiter und
    # bricht erst zur Laufzeit beim DI-Aufloesen oder beim Navigieren.
    #
    # Nur sinnvoll, wenn build_runner eben gelaufen ist. Ohne ihn (-Regeln)
    # verglichen der Schritt den Arbeitsstand mit sich selbst und meldete
    # lediglich, dass die Dateien noch nicht committet sind — ein Befund ueber
    # den Zustand des Arbeitsverzeichnisses, nicht ueber den Code.
    if (-not $Regeln) {
        $frontendSchritte += New-Schritt 'Frontend: generierter Stand aktuell' $wurzel 'git' `
            @('diff', '--exit-code', '--',
              'Automation_App_Frontend/lib/core/di/injection.config.dart',
              'Automation_App_Frontend/lib/core/router/app_router.gr.dart') `
            -Hilfe 'build_runner hat die generierten Dateien geaendert: mit in denselben Commit nehmen.'
    }

    $frontendSchritte += New-Schritt 'Frontend: Formatierung' $frontend $dartBefehl `
        @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test') `
        -Hilfe 'dart format lib test — oder ./scripts/check.ps1 -Beheben'

    # --no-pub bei analyze und test: `pub get` steht schon als erster Schritt
    # oben. Ohne den Schalter holen beide es noch einmal nach.
    $frontendSchritte += New-Schritt 'Frontend: Analyse' $frontend $flutterBefehl @('analyze', '--no-pub')

    if ($Regeln) {
        # Dieselben Tests, nur der Ordner statt der ganzen Suite: Alles unter
        # test/architecture/ liest Quelltext und Doku und fuehrt nichts von der
        # Anwendung aus — es prueft Regeln, nicht Verhalten.
        $frontendSchritte += New-Schritt 'Frontend: Architektur-Tests' $frontend $flutterBefehl `
            @('test', '--no-pub', "--concurrency=$testNebenlaeufigkeit", 'test/architecture') `
            -Hilfe 'Schichten, Dateilaenge, private Typen, Benennung, HTTP-Vertrag, Doku, Anforderungsverweise.'
    }
    else {
        $frontendSchritte += New-Schritt 'Frontend: Tests' $frontend $flutterBefehl `
            @('test', '--no-pub', "--concurrency=$testNebenlaeufigkeit") `
            -Hilfe 'Enthaelt die Architektur-Tests (Schichten, Dateilaenge, private Typen, HTTP-Vertrag).'
    }
}

$backendSchritte = @()
if (-not $NurFrontend) {
    # Waechter fuer den Filter weiter unten. `dotnet test --filter` liefert eine
    # 0, wenn der Filter *nichts* trifft — nachgemessen, samt der Meldung "Kein
    # Test entspricht dem angegebenen Testfallfilter". Ein umbenannter Ordner
    # machte -Regeln damit still gruen, ohne eine einzige Regel zu pruefen: die
    # schlimmste Sorte Pruefung, weil sie Sicherheit behauptet, die sie nicht
    # hat. Auf der Dart-Seite gibt es das Loch nicht, `flutter test` bricht bei
    # einem Pfad ohne Entsprechung mit 1 ab.
    #
    # Geprueft wird der Ordner, nicht der Namespace — NamespaceKonventionTests
    # erzwingt "Namespace = Ordnerpfad", der Pfad deckt den Filter also ab.
    $regelOrdner = Join-Path $backend 'AutomationService.Tests/Architecture'
    if ($Regeln -and -not (Test-Path -LiteralPath $regelOrdner)) {
        Write-Host ''
        Write-Host "Die Regeltests des Backends liegen nicht mehr unter $regelOrdner." -ForegroundColor Red
        Write-Host ('Der Filter in check.ps1 zeigt damit ins Leere, und -Regeln waere still gruen. ' +
                    'Ordner und Filter zusammen nachziehen.') -ForegroundColor Red
        exit 1
    }

    $backendSchritte += New-Schritt 'Backend: Build' $backend 'dotnet' `
        (@('build', 'AutomationService.Tests', '--configuration', 'Release') + $bauArgumente) `
        -Hilfe 'TreatWarningsAsErrors ist an: auch eine neue Analyzer-Warnung bricht hier ab.'

    if ($Regeln) {
        # Alle Regeltests des Backends liegen im Namespace
        # AutomationService.Tests.Architecture (Dateilaenge, Slice-Isolation,
        # Namespace-Konvention, Doku) — ein Ordner, ein Namespace, ein Filter.
        # Draussen bleibt damit auch der Vertragsexport nach docs/openapi.json:
        # Der startet den Dienst und ist die teuerste Einzelpruefung der Kette.
        $backendSchritte += New-Schritt 'Backend: Architektur-Tests' $backend 'dotnet' `
            (@('test', 'AutomationService.Tests', '--configuration', 'Release', '--no-build',
               '--filter', 'FullyQualifiedName~AutomationService.Tests.Architecture') + $bauArgumente) `
            -Hilfe 'Dateilaenge, Slice-Isolation, Namespace = Ordnerpfad, Doku-Steckbriefe.'
    }
    else {
        $backendSchritte += New-Schritt 'Backend: Tests' $backend 'dotnet' `
            (@('test', 'AutomationService.Tests', '--configuration', 'Release', '--no-build') + $bauArgumente) `
            -Hilfe 'Enthaelt die Architektur-Tests und den Vertragsexport nach docs/openapi.json.'
    }

    # Nur `whitespace`, nicht das ganze `dotnet format`:
    #
    # Directory.Build.props setzt EnforceCodeStyleInBuild und
    # TreatWarningsAsErrors — jede IDE-Regel und jeder Analyzer-Befund bricht
    # damit schon den Build oben. `dotnet format style` (28 s) und `analyzers`
    # (33 s) pruefen dieselben Regeln mit derselben Schwelle ein zweites Mal;
    # `whitespace` allein braucht 8. Gegenprobe gemacht: eine .cs-Datei auf LF
    # umgestellt — der Build meldet null Fehler, `whitespace` meldet ENDOFLINE.
    # Was der Compiler *nicht* sieht, sind also genau Zeilenenden, Kodierung und
    # Einrueckung, und genau daran scheitert hier regelmaessig etwas.
    #
    # Zwei Aufrufe, weil AutomationService.slnx nur das Dienstprojekt enthaelt:
    # das Testprojekt liegt zwar in dessen Ordner, ist aber per Compile Remove
    # ausgenommen und wurde deshalb bisher gar nicht geprueft.
    $formatZiele = @(
        @{ Kurz = 'Dienst'; Ziel = '../AutomationService.slnx' },
        @{ Kurz = 'Tests';  Ziel = 'AutomationService.Tests/AutomationService.Tests.csproj' }
    )

    if ($Beheben) {
        foreach ($z in $formatZiele) {
            $backendSchritte += New-Schritt "Backend: Formatierung beheben ($($z.Kurz))" $backend 'dotnet' `
                @('format', 'whitespace', $z.Ziel)
        }
    }

    foreach ($z in $formatZiele) {
        $backendSchritte += New-Schritt "Backend: Formatierung ($($z.Kurz))" $backend 'dotnet' `
            @('format', 'whitespace', $z.Ziel, '--verify-no-changes') `
            -Hilfe "dotnet format whitespace $($z.Ziel) — oder ./scripts/check.ps1 -Beheben"
    }
}

# ---------------------------------------------------------------------------
# Fahren
# ---------------------------------------------------------------------------

$seiten = @()
if ($frontendSchritte.Count -gt 0) { $seiten += @{ Name = 'Frontend'; Schritte = $frontendSchritte } }
if ($backendSchritte.Count  -gt 0) { $seiten += @{ Name = 'Backend';  Schritte = $backendSchritte  } }

$gesamtStart = Get-Date
$ergebnisse  = New-Object System.Collections.ArrayList

if ($seiten.Count -lt 2 -or -not $Gleichzeitig) {
    foreach ($seite in $seiten) {
        # Ohne Zuweisung und ohne Rohr, damit die Werkzeuge die Konsole des
        # Aufrufers erben (Begruendung oben bei $seiteFahren). Die Ergebnisse
        # kommen ueber die Senke zurueck, nicht ueber den Rueckgabestrom.
        & $seiteFahren $seite.Schritte $true $ergebnisse
    }
}
else {
    Write-Host ''
    Write-Host 'Frontend und Backend laufen gleichzeitig; die Ausgabe kommt je Seite am Stueck.' -ForegroundColor DarkCyan

    $auftraege = foreach ($seite in $seiten) {
        Start-Job -Name $seite.Name -ScriptBlock $seiteFahren -ArgumentList $seite.Schritte, $false
    }

    # 'NotStarted' zaehlt mit: bis die Laufzeitumgebung eines Auftrags steht,
    # vergeht ein Moment. Ohne diesen Zustand faellt die Schleife beim ersten
    # Durchgang durch, und der Fortschritt bliebe fuer den ganzen Lauf aus.
    $offeneZustaende = @('NotStarted', 'Running')

    while (@($auftraege | Where-Object { $offeneZustaende -contains $_.State }).Count -gt 0) {
        $offen = ($auftraege | Where-Object { $offeneZustaende -contains $_.State } | ForEach-Object { $_.Name }) -join ', '
        Write-Progress -Activity 'Pruefkette' `
            -Status ("laeuft: $offen ({0:N0} s)" -f ((Get-Date) - $gesamtStart).TotalSeconds)
        Start-Sleep -Milliseconds 500
    }
    Write-Progress -Activity 'Pruefkette' -Completed

    # In fester Reihenfolge ausgeben, nicht in der des Fertigwerdens: Zwei
    # Laeufe sollen dasselbe Protokoll ergeben.
    foreach ($seite in $seiten) {
        $auftrag = $auftraege | Where-Object { $_.Name -eq $seite.Name }

        # Gezielt das Ergebnisobjekt herausgreifen, statt zu nehmen, was kommt:
        # ein Auftrag kann fallen, ohne einen einzigen Schritt gefahren zu sein
        # (Fehler im Skriptblock, StrictMode-Verstoss, Argument, das sich nicht
        # serialisieren laesst). Dann liefert Receive-Job nichts oder einen
        # Fehlersatz, und ein blindes $lauf.Ausgabe braeche unter StrictMode mit
        # "Eigenschaft nicht gefunden" ab: die Zusammenfassung erschiene nie,
        # Remove-Job liefe nie, und die echte Ursache bliebe unsichtbar.
        $lauf = @(Receive-Job -Job $auftrag -Wait -ErrorAction SilentlyContinue) |
            Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'Ergebnisse' } |
            Select-Object -Last 1

        Write-Host ''
        Write-Host "======== $($seite.Name) ========" -ForegroundColor Cyan

        if ($null -eq $lauf) {
            $grund = (@($auftrag.ChildJobs | ForEach-Object { $_.JobStateInfo.Reason }) |
                Where-Object { $_ } | ForEach-Object { $_.Message }) -join '; '
            if (-not $grund) {
                $grund = "Der Auftrag endete im Zustand $($auftrag.State), ohne ein Ergebnis zu liefern."
            }
            Write-Host $grund -ForegroundColor Red
            $null = $ergebnisse.Add([pscustomobject]@{
                    Name     = "$($seite.Name): Auftrag"
                    Ok       = $false
                    Hilfe    = 'Der Hintergrundauftrag lief nicht an. Ohne -Gleichzeitig noch einmal fahren, dann steht der Fehler im Klartext da.'
                    Sekunden = 0
                })
            continue
        }

        Write-Host $lauf.Ausgabe
        foreach ($e in $lauf.Ergebnisse) { $null = $ergebnisse.Add($e) }
    }
    Remove-Job -Job $auftraege
}

# Das Ausweichverzeichnis ist ein Nebenprodukt dieses Laufs, kein Bauergebnis,
# das jemand weiterverwendet.
if ($dienstLaeuft -and (Test-Path $binPruef)) {
    Remove-Item $binPruef -Recurse -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Zusammenfassung
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '==== Zusammenfassung ====' -ForegroundColor Cyan
foreach ($e in $ergebnisse) {
    $zeile = '  {0} {1,6:N1} s  {2}' -f $(if ($e.Ok) { '[ok]    ' } else { '[FEHLER]' }), $e.Sekunden, $e.Name
    Write-Host $zeile -ForegroundColor $(if ($e.Ok) { 'Green' } else { 'Red' })
    if (-not $e.Ok -and $e.Hilfe) { Write-Host ('           ' + $e.Hilfe) -ForegroundColor DarkYellow }
}

foreach ($h in $hinweise) {
    Write-Host ('  [Hinweis] ' + $h) -ForegroundColor DarkCyan
}

$dauer = ((Get-Date) - $gesamtStart).TotalSeconds
$summe = ($ergebnisse | Measure-Object -Property Sekunden -Sum).Sum
Write-Host ''
Write-Host ('Gesamt {0:N0} s (Summe der Schritte {1:N0} s).' -f $dauer, $summe) -ForegroundColor DarkGray

$offen = @($ergebnisse | Where-Object { -not $_.Ok })
if ($offen.Count -gt 0) {
    Write-Host ("$($offen.Count) von $($ergebnisse.Count) Schritten fehlgeschlagen.") -ForegroundColor Red
    exit 1
}

Write-Host "Alle $($ergebnisse.Count) Schritte in Ordnung." -ForegroundColor Green
