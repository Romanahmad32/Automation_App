<#
.SYNOPSIS
    Rauchtest des gebauten Pakets: startet den ausgelieferten Dienst und wartet
    auf seine Bereitschaft.

.DESCRIPTION
    Unit- und Integrationstests laufen gegen den Quellcode. Sie sagen nichts
    darueber, ob die *veroeffentlichte* Exe hochkommt: fehlende Konfiguration,
    ein nicht aufloesbarer DI-Eintrag oder eine vergessene Datei im Paket
    brechen erst hier — und sonst erst beim Anwender.

    Geprueft wird bewusst nur der Dienst, nicht die Oberflaeche: eine GUI auf
    einem CI-Runner zu starten ist unzuverlaessig, waehrend der Dienst genau die
    Fehlerklasse abdeckt, um die es geht. Dass der Dienst ueberhaupt vom
    Frontend gestartet wird, sichern die Tests von BackendLauncher ab.

    Der Start migriert nebenbei die SQLite-Datenbank — auch das wird hier also
    zum ersten Mal an einer echten Datei ausgefuehrt.

.EXAMPLE
    ./scripts/smoke-test.ps1 -PackageDirectory dist/Automation_App -ExpectedVersion 1.2.0
#>
[CmdletBinding()]
param(
    # Ordner, den build-package.ps1 erzeugt hat (relativ oder absolut).
    [Parameter(Mandatory = $true)]
    [string]$PackageDirectory,

    # Wenn angegeben: der Health-Endpunkt muss diese Version melden.
    [string]$ExpectedVersion,

    # Port fuer den Testlauf. Bewusst nicht 5143, damit ein lokal laufender
    # Dienst den Test nicht faelschlich gruen macht.
    [int]$Port = 5199,

    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$paket = Resolve-Path $PackageDirectory
$exe = Join-Path $paket 'backend/AutomationService.exe'
if (-not (Test-Path $exe)) { throw "Dienst nicht gefunden: $exe" }

$url = "http://localhost:$Port"
Write-Host "== Rauchtest gegen $url ==" -ForegroundColor Cyan

# Word ist auf einem CI-Runner nicht installiert; das Vorwaermen der
# COM-Anbindung hat mit dem, was hier geprueft wird, nichts zu tun.
$env:PdfConversion__WarmupOnStartup = 'false'

$dienst = Start-Process $exe `
    -ArgumentList '--urls', $url `
    -PassThru -WindowStyle Hidden `
    -WorkingDirectory (Join-Path $paket 'backend')

try {
    $antwort = $null
    $frist = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $frist) {
        if ($dienst.HasExited) {
            throw "Der Dienst hat sich beim Start beendet (Rueckgabewert $($dienst.ExitCode))."
        }
        try {
            $antwort = Invoke-RestMethod "$url/health" -TimeoutSec 5
            break
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    }

    if ($null -eq $antwort) {
        throw "Der Dienst hat sich nicht innerhalb von $TimeoutSeconds Sekunden gemeldet."
    }

    Write-Host "health: status=$($antwort.status) version=$($antwort.version)"

    if ($antwort.status -ne 'bereit') {
        throw "Health meldet '$($antwort.status)' statt 'bereit'."
    }

    if ($ExpectedVersion -and -not $antwort.version.StartsWith($ExpectedVersion)) {
        throw "Health meldet Version '$($antwort.version)', erwartet wurde '$ExpectedVersion'. " +
              "Die Version wird also nicht in die Assembly durchgereicht."
    }

    Write-Host "== Rauchtest bestanden ==" -ForegroundColor Green
}
finally {
    if (-not $dienst.HasExited) {
        Stop-Process -Id $dienst.Id -Force
    }
}
