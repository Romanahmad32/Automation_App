<#
.SYNOPSIS
    Startet Dienst und App im Testmodus -- abgeschottet vom echten Bestand --
    und beendet sie wieder.

.DESCRIPTION
    Fuer die E2E-Abnahme per Marionette und fuer die integration_test-Suite
    (Issue #184). Der Testmodus (Issue #168) sorgt dafuer, dass nichts nach
    aussen wirkt und nichts Echtes beruehrt wird:

      * Datenordner: Der Dienst bekommt `--Datenordner <Wurzel>\daten` und legt
        Datenbank, Vorlagen und Protokoll dort ab, nie unter %APPDATA%.
      * Umgebung `E2E` (`appsettings.E2E.json`): Port 5243, `Simulation:Testmodus`
        an -- Zentralruf, Versand, Gesendet-Ablage, Entwurf und Druck sind
        Attrappen, die ihre Spuren unter `daten\Testmodus\` ablegen
        (`protokoll.jsonl`, `Versand\`, `Entwuerfe\`, `Druck\`).
      * Eigener ContentRoot: Der Dienst wird nach `<Wurzel>\dienst` gebaut und
        von dort gestartet, damit er sich `Generated\` nicht mit einem
        Entwicklungsdienst teilt.

    Sicherheitsschranken: Der Port darf nicht belegt sein; der Dienst muss in
    `/health` `testmodus=true` melden UND `daten\automation.db` muss existieren
    (beweist, dass der Datenordner gegriffen hat). Erst danach wird irgendetwas
    angelegt. Besteht eine Schranke nicht, wird der Dienst wieder beendet.

    Die App startet mit `test_driver/main_marionette.dart` und den Dart-Defines
    `AUTOMATION_BACKEND_PORT` und `AUTOMATION_TESTMODUS=true`. Ihre VM-Service-
    Adresse (fuer Marionette `connect`) steht in `<Wurzel>\vmservice.txt` und
    wird ausgegeben.

    Der Zustand steht in `<Wurzel>\e2e.json`; `-Beenden` liest ihn.
    Dieses Skript laeuft nur lokal, nie in der CI.

.PARAMETER Port
    Port des Testmodus-Dienstes (Vorgabe 5243, nicht 5143).

.PARAMETER Wurzel
    E2E-Wurzelordner. Vorgabe: %TEMP%\automation-e2e\<yyyyMMdd-HHmmss>.

.PARAMETER OhneApp
    Nur den Dienst starten (fuer die integration_test-Suite).

.PARAMETER OhneTestdaten
    e2e-testdaten.ps1 nicht aufrufen.

.PARAMETER Beenden
    Beendet Dienst und App des letzten Laufs (oder des mit -Wurzel angegebenen)
    laut e2e.json. Der Ordner bleibt zum Nachsehen liegen.

.PARAMETER TimeoutSeconds
    Wartezeit auf Dienst und auf die App (der erste Windows-Build dauert).

.EXAMPLE
    ./scripts/e2e-start.ps1

.EXAMPLE
    ./scripts/e2e-start.ps1 -OhneApp

.EXAMPLE
    ./scripts/e2e-start.ps1 -Beenden
#>
[CmdletBinding()]
param(
    [ValidateScript({
        if ($_ -eq 5143) { throw 'Port 5143 ist der Port der installierten App und fuer den Testmodus gesperrt.' }
        $true
    })]
    [int]$Port = 5243,
    [string]$Wurzel,
    [switch]$OhneApp,
    [switch]$OhneTestdaten,
    [switch]$Beenden,
    [int]$TimeoutSeconds = 300,
    # Eigene Frist fuer die App: Der erste Windows-Build eines Worktrees dauert
    # unter Last laenger als 300 s (gemessen 13.10.2026: abgebrochen nach 300 s,
    # warm danach 127 s).
    [int]$AppTimeoutSeconds = 900
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path $PSScriptRoot -Parent
$wurzelBasis = Join-Path $env:TEMP 'automation-e2e'

function Schreibe-Zustand($Zustand, [string]$Pfad) {
    # UTF-8 ohne BOM: Set-Content -Encoding UTF8 schriebe in 5.1 ein BOM.
    $json = $Zustand | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($Pfad, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Beende-Baum([int]$ProzessId) {
    if ($ProzessId -le 0) { return }
    # In Windows PowerShell 5.1 wird stderr eines nativen Programms unter
    # $ErrorActionPreference='Stop' zum terminierenden Fehler ("Prozess nicht
    # gefunden" ist ein normaler Fall). Darum hier 'Continue' und ein try, damit
    # der Aufrufer nach dem ersten Ziel immer noch das zweite beendet und ein
    # Originalfehler im finally nicht ueberdeckt wird.
    $vorher = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # taskkill /T nimmt Kindprozesse mit (flutter.bat -> dart -> automation_app.exe).
        & taskkill.exe /PID $ProzessId /T /F 2>&1 | Out-Null
    }
    catch { }
    finally { $ErrorActionPreference = $vorher }
}

function Port-Belegt([int]$Nummer) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $ergebnis = $client.BeginConnect('127.0.0.1', $Nummer, $null, $null)
        if ($ergebnis.AsyncWaitHandle.WaitOne(500)) {
            try { $client.EndConnect($ergebnis); return $true } catch { return $false }
        }
        return $false
    }
    finally { $client.Close() }
}

# --- -Beenden ---------------------------------------------------------------
if ($Beenden) {
    if (-not $Wurzel) {
        $letzte = Get-ChildItem $wurzelBasis -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'e2e.json') } |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($null -eq $letzte) { throw "Kein E2E-Lauf unter $wurzelBasis gefunden." }
        $Wurzel = $letzte.FullName
    }
    $zustandPfad = Join-Path $Wurzel 'e2e.json'
    if (-not (Test-Path $zustandPfad)) { throw "Keine e2e.json in $Wurzel." }
    $zustand = Get-Content $zustandPfad -Raw | ConvertFrom-Json
    Beende-Baum ([int]$zustand.appPid)
    Beende-Baum ([int]$zustand.dienstPid)
    Write-Host "== E2E-Lauf beendet: $Wurzel (Ordner bleibt liegen) ==" -ForegroundColor Green
    return
}

# --- Start ------------------------------------------------------------------
if (-not $Wurzel) { $Wurzel = Join-Path $wurzelBasis (Get-Date -Format 'yyyyMMdd-HHmmss') }
$Wurzel = [System.IO.Path]::GetFullPath($Wurzel)
$dienstOrdner = Join-Path $Wurzel 'dienst'
$datenOrdner = Join-Path $Wurzel 'daten'
$url = "http://localhost:$Port"

Write-Host "== E2E-Testmodus: $url, Wurzel $Wurzel ==" -ForegroundColor Cyan

if (Port-Belegt $Port) {
    throw "Port $Port ist belegt -- laeuft schon ein E2E-Dienst? Mit -Beenden stoppen oder -Port waehlen."
}

New-Item -ItemType Directory -Path $dienstOrdner, $datenOrdner -Force | Out-Null

Write-Host '-- Dienst bauen (Debug) nach dienst\' -ForegroundColor Cyan
$csproj = Join-Path $repo 'AutomationService\AutomationService\AutomationService.csproj'
# Ohne NuGet-Audit: Die Sicherheitspruefung der Pakete gehoert in CI und check.ps1.
# Dieser Bau wird nie ausgeliefert und soll nicht an einem unerreichbaren
# Paketfeed scheitern (NU1900 wird durch TreatWarningsAsErrors zum Fehler).
dotnet build $csproj -c Debug -o $dienstOrdner --nologo -p:NuGetAudit=false
if ($LASTEXITCODE -ne 0) { throw 'dotnet build ist fehlgeschlagen.' }

$exe = Join-Path $dienstOrdner 'AutomationService.exe'
if (-not (Test-Path $exe)) { throw "Dienst nicht gefunden: $exe" }

$dienstProzess = $null
$app = $null
$erfolg = $false
$zustandPfad = Join-Path $Wurzel 'e2e.json'
try {
    Write-Host '-- Dienst starten (Umgebung E2E)' -ForegroundColor Cyan
    # Pfade in Anfuehrungszeichen: Start-Process reicht ArgumentList sonst
    # ungeschuetzt weiter, und ein Benutzername mit Leerzeichen bricht den Start.
    $argumente = "--environment E2E --urls $url --Datenordner `"$datenOrdner`""
    $dienstProzess = Start-Process $exe -ArgumentList $argumente -PassThru -WindowStyle Hidden `
        -WorkingDirectory $dienstOrdner `
        -RedirectStandardOutput (Join-Path $Wurzel 'dienst.log') `
        -RedirectStandardError (Join-Path $Wurzel 'dienst.err.log')

    $zustand = [ordered]@{
        port = $Port; dienstPid = $dienstProzess.Id; appPid = 0; wurzel = $Wurzel
        datenordner = $datenOrdner; testmodusOrdner = (Join-Path $datenOrdner 'Testmodus'); vmService = $null
    }
    Schreibe-Zustand $zustand $zustandPfad

    $antwort = $null
    $frist = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $frist) {
        if ($dienstProzess.HasExited) {
            throw "Der Dienst hat sich beim Start beendet (Rueckgabewert $($dienstProzess.ExitCode)). Siehe dienst.log und dienst.err.log in $Wurzel."
        }
        try { $antwort = Invoke-RestMethod "$url/health" -TimeoutSec 5; if ($antwort.status -eq 'bereit') { break } }
        catch { }
        $antwort = $null
        Start-Sleep -Milliseconds 500
    }
    if ($null -eq $antwort) { throw "Der Dienst hat sich nicht innerhalb von $TimeoutSeconds Sekunden gemeldet." }

    # Schranke 1: testmodus ausdruecklich true.
    $feld = $antwort.PSObject.Properties['testmodus']
    if ($null -eq $feld -or $feld.Value -ne $true) {
        throw "Der Dienst meldet keinen Testmodus (testmodus != true) -- abgebrochen und beendet."
    }
    # Schranke 2: Die Datenbank liegt im Datenordner (der Umlenkung gegriffen hat).
    if (-not (Test-Path (Join-Path $datenOrdner 'automation.db'))) {
        throw "Im Datenordner liegt keine automation.db -- der Datenordner hat nicht gegriffen. Abgebrochen und beendet."
    }
    Write-Host "health: status=$($antwort.status) version=$($antwort.version) testmodus=$($antwort.testmodus)" -ForegroundColor Green

    if (-not $OhneTestdaten) {
        & (Join-Path $PSScriptRoot 'e2e-testdaten.ps1') -Port $Port -Wurzel $Wurzel
    }

    if (-not $OhneApp) {
        Write-Host '-- App starten (Marionette-Einstieg)' -ForegroundColor Cyan
        $sdkBin = & (Join-Path $PSScriptRoot 'versionspruefung.ps1') -NurFrontend
        if ($LASTEXITCODE -ne 0) { throw 'Die Toolchain-Pruefung ist fehlgeschlagen (siehe oben).' }
        $flutter = if ($sdkBin) { Join-Path $sdkBin 'flutter.bat' } else { 'flutter' }

        $vmDatei = Join-Path $Wurzel 'vmservice.txt'
        if (Test-Path $vmDatei) { Remove-Item $vmDatei -Force }
        $flutterArgumente = "run -d windows -t test_driver/main_marionette.dart " +
            "--dart-define=AUTOMATION_BACKEND_PORT=$Port --dart-define=AUTOMATION_TESTMODUS=true " +
            "--vmservice-out-file `"$vmDatei`""
        # Eigenes Fenster: `flutter run` bleibt interaktiv (r = Hot Reload).
        $app = Start-Process $flutter -ArgumentList $flutterArgumente -PassThru `
            -WorkingDirectory (Join-Path $repo 'Automation_App_Frontend')
        $zustand.appPid = $app.Id
        Schreibe-Zustand $zustand $zustandPfad

        Write-Host "   (der erste Build eines Worktrees dauert einige Minuten; Frist $AppTimeoutSeconds s)"
        $vmAdresse = $null
        $frist = (Get-Date).AddSeconds($AppTimeoutSeconds)
        while ((Get-Date) -lt $frist) {
            if ($app.HasExited) { throw "flutter run hat sich beendet (Rueckgabewert $($app.ExitCode))." }
            if ((Test-Path $vmDatei) -and ((Get-Item $vmDatei).Length -gt 0)) {
                $vmAdresse = (Get-Content $vmDatei -Raw).Trim()
                break
            }
            Start-Sleep -Seconds 1
        }
        if (-not $vmAdresse) { throw "Die App hat sich nicht innerhalb von $AppTimeoutSeconds Sekunden gemeldet (keine vmservice.txt)." }
        $zustand.vmService = $vmAdresse
        Schreibe-Zustand $zustand $zustandPfad
        Write-Host "VM-Service fuer Marionette connect: $vmAdresse" -ForegroundColor Green
    }

    $erfolg = $true
    Write-Host "== E2E-Testmodus laeuft. Testmodus-Spuren: $($zustand.testmodusOrdner) ==" -ForegroundColor Green
    Write-Host "   Beenden: ./scripts/e2e-start.ps1 -Beenden"
}
finally {
    if (-not $erfolg) {
        if ($null -ne $app) { Beende-Baum $app.Id }
        if ($null -ne $dienstProzess -and -not $dienstProzess.HasExited) { Beende-Baum $dienstProzess.Id }
    }
}
