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

    Fuer Flutter gilt: liegt das projektlokale FVM-SDK vor (fvm use in
    Automation_App_Frontend, siehe docs/RELEASE.md), wird genau dessen
    Fassung geprueft — und der Pfad bei Erfolg auf stdout gemeldet, damit
    check.ps1 die Frontend-Schritte mit demselben SDK faehrt. FVM ist
    Angebot, nicht Pflicht: ohne .fvm/ zaehlt das Flutter aus dem PATH.

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
    $ciDatei = Join-Path $wurzel '.github/workflows/ci.yml'
    $gepinnt = [regex]::Match((Get-Content $ciDatei -Raw), 'FLUTTER_VERSION:\s*"([^"]+)"').Groups[1].Value

    # .fvmrc pinnt dieselbe Fassung ein zweites Mal, weil fvm nur sie liest.
    # Laufen die beiden auseinander, benutzte die Kette hier ein anderes SDK,
    # als die CI prueft — genau der Zustand, den dieses Skript verhindert.
    $fvmrc = Join-Path $wurzel 'Automation_App_Frontend/.fvmrc'
    if ($gepinnt -and (Test-Path $fvmrc)) {
        $fvmrcFassung = (Get-Content $fvmrc -Raw | ConvertFrom-Json).flutter
        if ($fvmrcFassung -ne $gepinnt) {
            $fehler += ".fvmrc nennt Flutter $fvmrcFassung, ci.yml FLUTTER_VERSION $gepinnt. " +
                'Ein Versionssprung aendert beide zusammen, in einem eigenen Commit (docs/RELEASE.md).'
        }
    }

    $fvmBin = Join-Path $wurzel 'Automation_App_Frontend/.fvm/flutter_sdk/bin'
    $flutterBefehl = 'flutter'
    if (Test-Path (Join-Path $fvmBin 'flutter.bat')) {
        $sdkBin = $fvmBin
        $flutterBefehl = Join-Path $fvmBin 'flutter.bat'
    }

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
        # Nur die erste Zeile ("Flutter 3.41.2 • channel stable • ...") — der
        # Aufruf kostet ein paar Sekunden, ist aber der einzige Weg, der auch
        # eine per PATH gewechselte Installation ehrlich beantwortet.
        $zeile = [string](& $flutterBefehl --version 2>$null | Select-Object -First 1)
        $installiert = [regex]::Match($zeile, 'Flutter\s+(\S+)').Groups[1].Value
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
