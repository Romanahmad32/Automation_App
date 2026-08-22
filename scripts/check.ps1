<#
.SYNOPSIS
    Faehrt die komplette Pruefkette des Repos — dieselben Schritte wie die CI.

.DESCRIPTION
    Frontend und Backend liegen in verschiedenen Verzeichnissen und brauchen
    zusammen acht Befehle in einer bestimmten Reihenfolge. Wer einen davon
    vergisst, haelt seine Aenderung fuer fertig und laesst die CI die Arbeit
    machen — oder, schlimmer, merkt den Bruch erst beim Anwender: ein
    vergessener build_runner-Lauf bleibt in "flutter analyze" und
    "flutter test" unsichtbar und faellt erst zur Laufzeit auf.

    Das Skript bricht nicht beim ersten Fehler ab, sondern faehrt alle Schritte
    und fasst am Ende zusammen. Ein Durchlauf soll das vollstaendige Bild
    liefern, nicht nur den ersten Stolperstein.

    Ausgenommen sind bewusst die langlaufenden Paket-Schritte (build-package.ps1
    und smoke-test.ps1). Die gehoeren in die CI und ins Release, nicht in die
    Schleife waehrend der Arbeit.

.EXAMPLE
    ./scripts/check.ps1
    ./scripts/check.ps1 -NurFrontend
#>
[CmdletBinding()]
param(
    [switch]$NurFrontend,
    [switch]$NurBackend
)

Set-StrictMode -Version Latest

$wurzel   = Split-Path -Parent $PSScriptRoot
$frontend = Join-Path $wurzel 'Automation_App_Frontend'
$backend  = Join-Path $wurzel 'AutomationService/AutomationService'

$ergebnisse = New-Object System.Collections.ArrayList

function Invoke-Schritt {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Verzeichnis,
        [Parameter(Mandatory = $true)][string]$Datei,
        [Parameter(Mandatory = $true)][string[]]$Argumente,
        # Was zu tun ist, wenn der Schritt faellt. Erscheint in der Zusammenfassung.
        [string]$Hilfe = ''
    )

    Write-Host ''
    Write-Host "---- $Name" -ForegroundColor Cyan
    Push-Location $Verzeichnis
    try {
        & $Datei @Argumente
        $code = $LASTEXITCODE
    }
    catch {
        Write-Host $_ -ForegroundColor Red
        $code = 1
    }
    finally {
        Pop-Location
    }

    $null = $ergebnisse.Add([pscustomobject]@{
        Name  = $Name
        Ok    = ($code -eq 0)
        Hilfe = $Hilfe
    })
}

if (-not $NurBackend) {
    Invoke-Schritt -Name 'Frontend: Abhaengigkeiten' -Verzeichnis $frontend `
        -Datei 'flutter' -Argumente @('pub', 'get')

    Invoke-Schritt -Name 'Frontend: Codegenerierung' -Verzeichnis $frontend `
        -Datei 'dart' -Argumente @('run', 'build_runner', 'build', '--delete-conflicting-outputs') `
        -Hilfe 'Fehler in einer Annotation oder in build.yaml — nicht in den generierten Dateien selbst.'

    # Die generierten Dateien sind versioniert. Weichen sie nach dem Lauf ab,
    # war der committete Stand veraltet: die Anwendung uebersetzt weiter und
    # bricht erst zur Laufzeit beim DI-Aufloesen oder beim Navigieren.
    Invoke-Schritt -Name 'Frontend: generierter Stand aktuell' -Verzeichnis $wurzel `
        -Datei 'git' -Argumente @('diff', '--exit-code', '--',
            'Automation_App_Frontend/lib/core/di/injection.config.dart',
            'Automation_App_Frontend/lib/core/router/app_router.gr.dart') `
        -Hilfe 'build_runner hat die generierten Dateien geaendert: mit in denselben Commit nehmen.'

    Invoke-Schritt -Name 'Frontend: Formatierung' -Verzeichnis $frontend `
        -Datei 'dart' -Argumente @('format', '--output=none', '--set-exit-if-changed', 'lib', 'test') `
        -Hilfe 'dart format lib test'

    Invoke-Schritt -Name 'Frontend: Analyse' -Verzeichnis $frontend `
        -Datei 'flutter' -Argumente @('analyze')

    Invoke-Schritt -Name 'Frontend: Tests' -Verzeichnis $frontend `
        -Datei 'flutter' -Argumente @('test') `
        -Hilfe 'Enthaelt die Architektur-Tests (Schichten, Dateilaenge, private Typen, HTTP-Vertrag).'
}

if (-not $NurFrontend) {
    Invoke-Schritt -Name 'Backend: Build' -Verzeichnis $backend `
        -Datei 'dotnet' -Argumente @('build', 'AutomationService.Tests', '--configuration', 'Release') `
        -Hilfe 'TreatWarningsAsErrors ist an: auch eine neue Analyzer-Warnung bricht hier ab.'

    Invoke-Schritt -Name 'Backend: Tests' -Verzeichnis $backend `
        -Datei 'dotnet' -Argumente @('test', 'AutomationService.Tests', '--configuration', 'Release', '--no-build') `
        -Hilfe 'Enthaelt die Architektur-Tests und den Vertragsexport nach docs/openapi.json.'

    Invoke-Schritt -Name 'Backend: Formatierung' -Verzeichnis $backend `
        -Datei 'dotnet' -Argumente @('format', '../AutomationService.slnx', '--verify-no-changes') `
        -Hilfe 'dotnet format ../AutomationService.slnx'
}

Write-Host ''
Write-Host '==== Zusammenfassung ====' -ForegroundColor Cyan
foreach ($e in $ergebnisse) {
    if ($e.Ok) {
        Write-Host ('  [ok]     ' + $e.Name) -ForegroundColor Green
    }
    else {
        Write-Host ('  [FEHLER] ' + $e.Name) -ForegroundColor Red
        if ($e.Hilfe) { Write-Host ('           ' + $e.Hilfe) -ForegroundColor DarkYellow }
    }
}

$offen = @($ergebnisse | Where-Object { -not $_.Ok })
if ($offen.Count -gt 0) {
    Write-Host ''
    Write-Host ("$($offen.Count) von $($ergebnisse.Count) Schritten fehlgeschlagen.") -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host "Alle $($ergebnisse.Count) Schritte in Ordnung." -ForegroundColor Green
