<#
.SYNOPSIS
    Prueft die installierten Werkzeugfassungen gegen die gepinnten.

.DESCRIPTION
    Die Pruefkette verlaesst sich auf die gepinnte Toolchain: ci.yml legt die
    Flutter-Fassung fest, global.json das .NET-SDK. Laeuft sie mit einer
    anderen, entstehen Fehler, die wie Codefehler aussehen, aber keine sind:
    ein fremdes Flutter schreibt pubspec.lock um und faellt durch die
    Sperrdatei-Pruefung, ein fremdes SDK bringt eine andere Analyzer-
    Generation mit und bricht den Build. Auf einem Rechner mit abweichender
    Toolchain waren das zuletzt sechs rote Schritte ohne einen einzigen
    Defekt im Repo — und wer solche Laeufe oft sieht, lernt das Falsche:
    rote Schritte wegzuerklaeren.

    Fuer Flutter loest das Skript das SDK selbst auf: zuerst die projektlokale
    Junction .fvm/flutter_sdk (aus `fvm use`), sonst die in .fvmrc gepinnte
    Fassung im FVM-Cache. Geprueft wird die Fassung, die dabei herauskommt —
    und der Pfad bei Erfolg auf stdout gemeldet, damit check.ps1 die
    Frontend-Schritte mit demselben SDK faehrt. Die Junction ist gitignored;
    ohne den Weg ueber den Cache verweigerte die Kette in jedem frischen Klon
    und jedem neuen Worktree den Dienst, obwohl das richtige SDK dalag. FVM
    ist Angebot, nicht Pflicht: findet sich keins von beidem, zaehlt das
    Flutter aus dem PATH.

    check.ps1 ruft dieses Skript als allerersten Schritt und bricht ab, wenn
    es fehlschlaegt. Von Hand aufgerufen sagt es einem frisch aufgesetzten
    Rechner, was zu installieren ist.

.PARAMETER NurFrontend
    Prueft nur Flutter — dieselbe Bedeutung wie bei check.ps1.

.PARAMETER NurBackend
    Prueft nur das .NET-SDK.

.EXAMPLE
    ./scripts/versionspruefung.ps1
#>
[CmdletBinding()]
param(
    [switch]$NurFrontend,
    [switch]$NurBackend
)

Set-StrictMode -Version Latest

$wurzel = Split-Path -Parent $PSScriptRoot
$fehler = @()
$sdkBin = ''

if (-not $NurBackend) {
    # Die gepinnte Fassung von dort lesen, wo sie gilt (ci.yml), statt sie
    # hier zu wiederholen: zwei Stellen liefen auseinander, und dieses Skript
    # pruefte dann gegen die falsche.
    #
    # Erst pruefen, ob die Datei da ist: `Get-Content` auf einen fehlenden Pfad
    # ist ein *nicht* abbrechender Fehler. Das Skript lief bisher darueber
    # hinweg, jede folgende Zeile brach an $gepinnt ab, kein einziges $fehler
    # wurde gesetzt — und es endete mit 0. check.ps1 sah einen bestandenen
    # Versionsvergleich, der nie stattgefunden hatte, und fuhr die ganze Kette
    # gegen ein ungeprueftes Flutter. Ein Waechter, der bei eigener Stoerung
    # gruen meldet, ist schlimmer als keiner.
    $ciDatei = Join-Path $wurzel '.github/workflows/ci.yml'
    $gepinnt = ''
    if (Test-Path -LiteralPath $ciDatei) {
        $inhalt = Get-Content -LiteralPath $ciDatei -Raw
        $gepinnt = [regex]::Match($inhalt, 'FLUTTER_VERSION:\s*"([^"]+)"').Groups[1].Value
    }

    # .fvmrc pinnt dieselbe Fassung ein zweites Mal, weil fvm nur sie liest.
    # Laufen die beiden auseinander, benutzte die Kette hier ein anderes SDK,
    # als die CI prueft — genau der Zustand, den dieses Skript verhindert.
    $fvmrc = Join-Path $wurzel 'Automation_App_Frontend/.fvmrc'
    $fvmrcFassung = ''
    if (Test-Path -LiteralPath $fvmrc) {
        $fvmrcFassung = (Get-Content -LiteralPath $fvmrc -Raw | ConvertFrom-Json).flutter
        if ($gepinnt -and $fvmrcFassung -ne $gepinnt) {
            $fehler += ".fvmrc nennt Flutter $fvmrcFassung, ci.yml FLUTTER_VERSION $gepinnt. " +
                'Ein Versionssprung aendert beide zusammen, in einem eigenen Commit (docs/RELEASE.md).'
        }
    }

    # Wo das SDK gesucht wird, in dieser Reihenfolge:
    #
    #   1. .fvm/flutter_sdk — die Junction aus `fvm use`. Wer sie gelegt hat,
    #      hat das mit Absicht getan und bekommt genau dieses SDK, auch wenn im
    #      Cache noch andere Fassungen liegen.
    #   2. Die gepinnte Fassung im FVM-Cache.
    #
    # Der zweite Weg ist der wichtigere, weil die Junction gitignored ist: In
    # einem frischen Klon und in jedem neuen Worktree fehlt sie *immer*, das
    # SDK aber liegt auf einem Rechner, der hier schon gearbeitet hat, laengst
    # im Cache. Ohne diesen Schritt fiel die Pruefung dort auf das Flutter aus
    # dem PATH zurueck und brach aus reinen Umgebungsgruenden ab — und wer die
    # Kette regelmaessig ohne Defekt rot sieht, lernt das Falsche: rote
    # Schritte wegzuerklaeren.
    #
    # Nachinstalliert wird dabei nichts. Fehlt die Fassung auch im Cache,
    # bleibt es beim Abbruch weiter unten mit dem Hinweis auf `fvm install`:
    # ein *pruefendes* Skript soll weder den Arbeitsbaum aendern noch
    # ungefragt ins Netz greifen.
    # Gesucht wird nach .fvmrc, denn nur die liest fvm beim Anlegen des Cache-
    # Eintrags. Fehlt sie, zaehlt die Pinnung aus ci.yml: Ein Klon ohne .fvmrc
    # soll nicht stillschweigend am Cache vorbeilaufen — und wichen die beiden
    # voneinander ab, stuende der Abbruch schon oben.
    $kandidaten = @(Join-Path $wurzel 'Automation_App_Frontend/.fvm/flutter_sdk/bin')
    $imCache = if ($fvmrcFassung) { $fvmrcFassung } else { $gepinnt }
    if ($imCache) {
        # fvm legt seine SDKs unter <Cache>/versions/<Fassung> ab; der Cache
        # ist FVM_CACHE_PATH, sonst ~/fvm (nachzusehen in `fvm api context`).
        # Ein per `fvm config --cache-path` verstellter Cache steht nur in
        # fvms eigener Konfiguration und bleibt hier unsichtbar — dann greift
        # der Abbruch unten, nicht ein falsches SDK.
        $fvmCache = if ($env:FVM_CACHE_PATH) { $env:FVM_CACHE_PATH } else { Join-Path $HOME 'fvm' }
        $kandidaten += Join-Path $fvmCache "versions/$imCache/bin"
    }

    # -LiteralPath, weil Test-Path den Pfad sonst als Platzhaltermuster liest:
    # Ein Klonpfad mit eckigen Klammern macht ein vorhandenes SDK unsichtbar,
    # und die Kette faellt genau so grundlos auf den PATH zurueck, wie sie es
    # ohne den Cache-Weg tat.
    foreach ($kandidat in $kandidaten) {
        if (Test-Path -LiteralPath (Join-Path $kandidat 'flutter.bat')) {
            $sdkBin = $kandidat
            break
        }
    }

    $flutterBefehl = if ($sdkBin) { Join-Path $sdkBin 'flutter.bat' } else { 'flutter' }

    if (-not $gepinnt) {
        $fehler += "In $ciDatei steht keine FLUTTER_VERSION mehr — die Pinnung ist " +
            'umgezogen, und dieses Skript muss ihr folgen.'
    }
    elseif ($flutterBefehl -eq 'flutter' -and -not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        $fehler += "Flutter ist nicht im PATH und kein FVM-SDK liegt vor. Gepinnt ist $gepinnt — " +
            "in Automation_App_Frontend 'fvm install $gepinnt' und 'fvm use $gepinnt' ausfuehren, " +
            'oder https://docs.flutter.dev/release/archive.'
    }
    else {
        # Die Versionszeile ("Flutter 3.41.2 • channel stable • ...") — der
        # Aufruf kostet ein paar Sekunden, ist aber der einzige Weg, der auch
        # eine per PATH gewechselte Installation ehrlich beantwortet.
        #
        # Gesucht wird die *erste passende* Zeile und nicht die erste
        # ueberhaupt (geaendert am 03.09.2026): Ein frisches Flutter schreibt
        # beim ersten Lauf einen Hinweis davor. Bisher lief dieses Skript nur
        # auf Entwicklerrechnern, wo das langst geschehen ist; seit
        # build-package.ps1 es ruft, laeuft es auch auf einem GitHub-Runner,
        # der jedes Mal frisch ist. Faende die Regex dort nichts, meldete der
        # Vergleich "Flutter  statt der gepinnten 3.41.2" und der Paketbau
        # braeche ab, ohne dass etwas fehlte.
        $ausgabe = @(& $flutterBefehl --version 2>$null)
        $installiert = ''
        foreach ($zeile in $ausgabe) {
            $treffer = [regex]::Match([string]$zeile, 'Flutter\s+(\d\S*)')
            if ($treffer.Success) {
                $installiert = $treffer.Groups[1].Value
                break
            }
        }
        if ($installiert -ne $gepinnt) {
            $fehler += "Flutter $installiert statt der gepinnten $gepinnt. In Automation_App_Frontend " +
                "'fvm install $gepinnt' und 'fvm use $gepinnt' ausfuehren (die Kette greift dann von " +
                'selbst zum SDK unter .fvm/) — oder die Pinnung anheben: eigener Commit mit ci.yml ' +
                'FLUTTER_VERSION, .fvmrc und pubspec.lock zusammen.'
        }
    }
}

if (-not $NurFrontend) {
    $sdkPinnung = (Get-Content (Join-Path $wurzel 'global.json') -Raw | ConvertFrom-Json).sdk

    # global.json setzt rollForward=latestPatch: jede installierte Fassung im
    # selben Feature-Band mit mindestens der gepinnten Patchstufe erfuellt die
    # Pinnung — dieselbe Aufloesung, die dotnet selbst faehrt. Aendert jemand
    # die Politik, muss dieser Vergleich mitziehen; deshalb wird sie hier
    # ausdruecklich geprueft statt stillschweigend angenommen.
    $rollForward = 'latestPatch'
    if ($sdkPinnung.PSObject.Properties.Name -contains 'rollForward') {
        $rollForward = $sdkPinnung.rollForward
    }

    if ($rollForward -ne 'latestPatch') {
        $fehler += "global.json setzt rollForward '$rollForward'; dieses Skript kennt nur " +
            'latestPatch. Den Vergleich in scripts/versionspruefung.ps1 nachziehen.'
    }
    elseif (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        $fehler += "dotnet ist nicht im PATH. Gepinnt ist SDK $($sdkPinnung.version) " +
            '(global.json): https://dotnet.microsoft.com/download'
    }
    else {
        $teile    = $sdkPinnung.version.Split('.')
        $patchPin = $teile[2]
        # .NET kodiert das Feature-Band in der Hunderterstelle der Patchnummer:
        # 103 ist Band 1, Patch 03 — 10.0.111 erfuellt 10.0.103, 10.0.204 nicht.
        $band    = $patchPin.Substring(0, $patchPin.Length - 2)
        $abPatch = [int]$patchPin.Substring($patchPin.Length - 2)

        $installierte = @(& dotnet --list-sdks 2>$null | ForEach-Object { ($_ -split '\s+')[0] })
        $passende = @($installierte | Where-Object {
                $t = $_.Split('.')
                $t.Count -eq 3 -and $t[0] -eq $teile[0] -and $t[1] -eq $teile[1] -and
                $t[2].Length -eq $patchPin.Length -and
                $t[2].Substring(0, $t[2].Length - 2) -eq $band -and
                [int]$t[2].Substring($t[2].Length - 2) -ge $abPatch
            })

        if ($passende.Count -eq 0) {
            $fehler += ".NET-SDK $($teile[0]).$($teile[1]).${band}xx ab $($sdkPinnung.version) fehlt " +
                "(global.json, rollForward latestPatch); installiert: $($installierte -join ', '). " +
                "SDK von https://dotnet.microsoft.com/download/dotnet/$($teile[0]).$($teile[1]) " +
                'installieren oder global.json in einem eigenen Commit anheben.'
        }
    }
}

if ($fehler.Count -gt 0) {
    Write-Host ''
    Write-Host '==== Werkzeugfassungen ====' -ForegroundColor Cyan
    foreach ($f in $fehler) {
        Write-Host "  [FEHLER] $f" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Kein Pruefschritt ist gelaufen: mit dieser Toolchain waeren seine Fehler irrefuehrend.' -ForegroundColor DarkYellow
    exit 1
}

# Nur bei Erfolg und nur auf stdout: der Aufrufer (check.ps1) faehrt die
# Frontend-Schritte mit genau dem SDK, das hier geprueft wurde.
if ($sdkBin) { Write-Output $sdkBin }
exit 0
