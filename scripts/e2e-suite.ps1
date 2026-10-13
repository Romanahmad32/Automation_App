<#
.SYNOPSIS
    Faehrt die E2E-Suite (integration_test) gegen einen frischen
    Testmodus-Dienst -- vor jedem Release-Tag.

.DESCRIPTION
    Issue #184. Jede `*_test.dart` unter integration_test/ ist ein Durchlauf;
    heute drei ueber die Hauptwege, bedient ueber Keys und eindeutige Texte,
    geprueft am Ergebnis (Testmodus\protokoll.jsonl, die abgelegten Dateien,
    der Bestand ueber REST):

      hauptweg_versand   Vorgang starten, Zentralruf (Attrappe), simulierte
                         Antwort, Anspruchsschreiben, Ablage, Versand:
                         genau eine .eml an Versicherung und Mandant, PDF dran
      vollmacht_drucken  Vollmacht drucken: Druck-Kopie und Vermerk am Vorgang
      mandant_zuordnen   Mandant anlegen und beim Vorgang starten zuordnen

    Ablauf: scripts/e2e-start.ps1 -OhneApp (Temp-Wurzel, Dienst in Umgebung
    E2E, Ausgangsbestand), dann je Durchlauf `flutter test
    integration_test/<name>_test.dart -d windows` mit Port, Testmodus und
    Testmodus-Ordner als Dart-Defines. Die Suite prueft selbst vor dem ersten
    Antippen, dass /health `testmodus: true` meldet. Der Dienst wird immer
    beendet, auch bei einem Fehler -- geordnet, damit seine Word-Instanz nicht
    verwaist (siehe e2e-start.ps1). Stirbt die Sitzung hart, endet der Anker
    mit ihr (-WaechterPid), und der Dienst faehrt ebenfalls herunter.

    Ein Aufruf je Datei, nicht `flutter test integration_test`: Auf Windows
    startet flutter (3.47) die App ab der zweiten Datei eines Aufrufs nicht
    mehr ("Error waiting for a debug connection: The log reader stopped
    unexpectedly", gemessen 13.10.2026). Jeder Durchlauf baut die App deshalb
    einmal (rund 45 s) und laeuft in einem eigenen Prozess.

    Die Durchlaeufe raeumen nicht auf, sie arbeiten mit eigenen Namen je Lauf;
    der Ordner bleibt zum Nachsehen liegen, die volle Ausgabe steht in
    <Wurzel>\suite.log.

    Nur lokal: nicht in check.ps1, nicht in der CI. Ersetzt weder die
    Sichtpruefung noch das Captcha noch den echten Druck.

.PARAMETER Durchlauf
    Nur diese Durchlaeufe (Dateiname ohne _test.dart), z. B. vollmacht_drucken.

.PARAMETER Port
    Port des Testmodus-Dienstes (Vorgabe 5243; 5143 ist gesperrt).

.PARAMETER FristMinuten
    Frist je `flutter test`-Aufruf in Minuten (Vorgabe 15). Laeuft sie ab, wird
    der Prozessbaum dieses einen flutter-Aufrufs (nur die selbst gestartete
    PID) beendet und der Durchlauf als ROT gemeldet.

.EXAMPLE
    ./scripts/e2e-suite.ps1

.EXAMPLE
    ./scripts/e2e-suite.ps1 -Durchlauf vollmacht_drucken
#>
[CmdletBinding()]
param(
    [string[]]$Durchlauf,
    [ValidateScript({
        if ($_ -eq 5143) { throw 'Port 5143 ist der Port der installierten App und fuer den Testmodus gesperrt.' }
        $true
    })]
    [int]$Port = 5243,
    # Frist je `flutter test`-Aufruf (Minuten). Gemessen: gut 1,5 Minuten je
    # Datei warm; die Vorgabe deckt auch den ersten Windows-Build eines Worktrees.
    [ValidateRange(1, 240)]
    [int]$FristMinuten = 15
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path $PSScriptRoot -Parent
$frontend = Join-Path $repo 'Automation_App_Frontend'
$wurzel = Join-Path (Join-Path $env:TEMP 'automation-e2e') (Get-Date -Format 'yyyyMMdd-HHmmss')
$log = Join-Path $wurzel 'suite.log'
$beginn = Get-Date

# Was auf der Konsole erscheint; alles steht in suite.log: Fortschritt, der
# Windows-Build und die Fehlerbloecke des Test-Frameworks. Ein Block endet mit
# einer Doppellinie (U+2550) -- als Zeichencode, damit das Skript ASCII bleibt.
$fortschritt = '^\d{2}:\d{2} \+\d+|Building Windows application|^Failing tests:|Failed to load'
$blockEnde = '^' + [string][char]0x2550 + '{20}'

# Durchlaeufe vor dem Dienststart bestimmen: Ein Tippfehler soll nicht erst
# nach dem Bau auffallen.
$dateien = @(Get-ChildItem (Join-Path $frontend 'integration_test') -Filter '*_test.dart' |
        Sort-Object Name | ForEach-Object { "integration_test/$($_.Name)" })
if ($Durchlauf) {
    $dateien = @(foreach ($name in $Durchlauf) {
            $datei = "integration_test/${name}_test.dart"
            if (-not (Test-Path (Join-Path $frontend $datei))) { throw "Kein Durchlauf '$name' ($datei)." }
            $datei
        })
}
if ($dateien.Count -eq 0) { throw 'Keine Durchlaeufe unter Automation_App_Frontend/integration_test gefunden.' }

$sdkBin = & (Join-Path $PSScriptRoot 'versionspruefung.ps1') -NurFrontend
if ($LASTEXITCODE -ne 0) { throw 'Die Toolchain-Pruefung ist fehlgeschlagen (siehe oben).' }
$flutter = if ($sdkBin) { Join-Path $sdkBin 'flutter.bat' } else { 'flutter' }

function Teste-Datei([string]$Datei, [string]$TestmodusOrdner, [System.IO.StreamWriter]$Schreiber) {
    $argumente = @(
        'test', $Datei, '-d', 'windows',
        "--dart-define=AUTOMATION_BACKEND_PORT=$Port",
        '--dart-define=AUTOMATION_TESTMODUS=true',
        "--dart-define=AUTOMATION_E2E_TESTMODUS_ORDNER=$TestmodusOrdner"
    )
    Write-Host "-- flutter $($argumente -join ' ')" -ForegroundColor Cyan
    $Schreiber.WriteLine("==== flutter $($argumente -join ' ')")
    # stderr eines nativen Programms wird unter 'Stop' zum Abbruch (PowerShell
    # 5.1); die Ausgabe ist UTF-8 und soll es in suite.log bleiben.
    $vorherFehler = $ErrorActionPreference
    $vorherKodierung = [Console]::OutputEncoding
    $ErrorActionPreference = 'Continue'
    [Console]::OutputEncoding = $Schreiber.Encoding
    $imFehlerblock = $false
    # Eigener Prozess statt Pipeline, damit die Frist greift: Eine Pipeline
    # blockiert, solange flutter schweigt. stdout und stderr werden zeilenweise
    # asynchron gelesen und in kurzen Takten gegen die Frist geprueft.
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $flutter
    $start.Arguments = ($argumente | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $start.WorkingDirectory = $frontend
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = $Schreiber.Encoding
    $start.StandardErrorEncoding = $Schreiber.Encoding
    $prozess = [System.Diagnostics.Process]::Start($start)
    $ende = (Get-Date).AddMinutes($FristMinuten)
    try {
        $leser = @($prozess.StandardOutput.ReadLineAsync(), $prozess.StandardError.ReadLineAsync())
        $strome = @($prozess.StandardOutput, $prozess.StandardError)
        while ($null -ne $leser[0] -or $null -ne $leser[1]) {
            $gelesen = $false
            for ($i = 0; $i -lt 2; $i++) {
                if ($null -eq $leser[$i] -or -not $leser[$i].IsCompleted) { continue }
                $gelesen = $true
                $zeile = $leser[$i].Result
                if ($null -eq $zeile) { $leser[$i] = $null; continue }
                $leser[$i] = $strome[$i].ReadLineAsync()
                $Schreiber.WriteLine($zeile)
                if ($zeile -match 'EXCEPTION CAUGHT BY') { $imFehlerblock = $true }
                if ($imFehlerblock -or $zeile -match $fortschritt) { Write-Host $zeile }
                if ($imFehlerblock -and $zeile -match $blockEnde) { $imFehlerblock = $false }
            }
            if ((Get-Date) -gt $ende) {
                $meldung = "FRIST UEBERSCHRITTEN: $Datei laeuft laenger als $FristMinuten min -- flutter (PID $($prozess.Id)) wird samt Kindprozessen beendet."
                Write-Host $meldung -ForegroundColor Red
                $Schreiber.WriteLine($meldung)
                # Nur den Baum der selbst gestarteten PID; nie nach Namen.
                & taskkill.exe /PID $prozess.Id /T /F 2>&1 | Out-Null
                return 1
            }
            if (-not $gelesen) { Start-Sleep -Milliseconds 100 }
        }
        $prozess.WaitForExit()
        return $prozess.ExitCode
    }
    finally {
        $Schreiber.Flush()
        [Console]::OutputEncoding = $vorherKodierung
        $ErrorActionPreference = $vorherFehler
    }
}

$ergebnisse = [ordered]@{}
try {
    # -WaechterPid: Stirbt diese Sitzung hart, endet der Anker mit ihr und der
    # Dienst faehrt geordnet herunter, statt 24 Stunden weiterzulaufen.
    & (Join-Path $PSScriptRoot 'e2e-start.ps1') -OhneApp -Port $Port -Wurzel $wurzel -WaechterPid $PID
    $zustand = Get-Content (Join-Path $wurzel 'e2e.json') -Raw | ConvertFrom-Json
    Write-Host "   (vollstaendige Ausgabe: $log)"
    $schreiber = New-Object System.IO.StreamWriter($log, $false, (New-Object System.Text.UTF8Encoding($false)))
    try {
        foreach ($datei in $dateien) {
            $ergebnisse[$datei] = Teste-Datei $datei $zustand.testmodusOrdner $schreiber
        }
    }
    finally { $schreiber.Dispose() }
}
finally {
    if (Test-Path (Join-Path $wurzel 'e2e.json')) {
        & (Join-Path $PSScriptRoot 'e2e-start.ps1') -Beenden -Wurzel $wurzel
    }
}

$sekunden = [int]((Get-Date) - $beginn).TotalSeconds
Write-Host ''
foreach ($eintrag in $ergebnisse.GetEnumerator()) {
    if ($eintrag.Value -eq 0) { Write-Host "  gruen  $($eintrag.Key)" -ForegroundColor Green }
    else { Write-Host "  ROT    $($eintrag.Key)" -ForegroundColor Red }
}
$rot = @($ergebnisse.Values | Where-Object { $_ -ne 0 }).Count
if ($rot -eq 0 -and $ergebnisse.Count -eq $dateien.Count) {
    Write-Host "== E2E-Suite gruen: $($dateien.Count) Durchlaeufe in $sekunden s. Spuren: $wurzel ==" -ForegroundColor Green
    exit 0
}
Write-Host "== E2E-Suite ROT: $rot von $($dateien.Count) Durchlaeufen nach $sekunden s. Ausgabe: $log ==" -ForegroundColor Red
exit 1
