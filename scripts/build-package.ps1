<#
.SYNOPSIS
    Baut das auslieferbare Paket: Flutter-Anwendung plus den lokalen Dienst im
    Unterordner "backend".

.DESCRIPTION
    Dieses Skript ist die einzige Stelle, an der das Paket zusammengesetzt wird.
    CI und Release-Workflow rufen dasselbe Skript auf — sonst baut der Release
    etwas anderes als das, was die CI getestet hat, und der Unterschied faellt
    erst beim Anwender auf.

    Die Version kommt von aussen (aus dem Git-Tag) und wird in beide Haelften
    geschrieben: in die Flutter-Anwendung und in die Assembly des Dienstes. Der
    Health-Endpunkt meldet sie danach zurueck, was den Rauchtest ueberpruefbar
    macht.

    Der Dienst wird self-contained veroeffentlicht: auf dem Kanzlei-PC soll
    niemand vorher eine .NET-Laufzeit installieren muessen.

.EXAMPLE
    ./scripts/build-package.ps1 -Version 1.2.0 -BuildNumber 42
#>
[CmdletBinding()]
param(
    # Dreistellige Version ohne fuehrendes "v", z. B. 1.2.0.
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    # Fortlaufende Build-Nummer; in der CI die Lauf-Nummer des Workflows.
    [string]$BuildNumber = '0',

    # Zielordner relativ zum Repository-Wurzelverzeichnis.
    [string]$OutputDirectory = 'dist/Automation_App'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path $PSScriptRoot -Parent
$frontend = Join-Path $repo 'Automation_App_Frontend'
$backendProject = Join-Path $repo 'AutomationService/AutomationService/AutomationService.csproj'
$ziel = Join-Path $repo $OutputDirectory

Write-Host "== Paket $Version+$BuildNumber wird gebaut ==" -ForegroundColor Cyan

if (Test-Path $ziel) { Remove-Item $ziel -Recurse -Force }
New-Item -ItemType Directory -Path $ziel -Force | Out-Null

# --- Frontend -------------------------------------------------------------
Write-Host "-- Flutter-Anwendung" -ForegroundColor Cyan
Push-Location $frontend
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get ist fehlgeschlagen." }

    flutter build windows --release --build-name=$Version --build-number=$BuildNumber
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows ist fehlgeschlagen." }
}
finally {
    Pop-Location
}

$flutterAusgabe = Join-Path $frontend 'build/windows/x64/runner/Release'
if (-not (Test-Path $flutterAusgabe)) {
    throw "Flutter-Ausgabe nicht gefunden: $flutterAusgabe"
}

# "flutter build" raeumt den Ausgabeordner nicht auf. Wer dort von Hand ein
# Paket zusammengesteckt hat (Dienst nach "backend\" kopiert, um den Start zu
# testen), haette dessen alten Stand sonst im naechsten Release. In der CI ist
# der Checkout frisch, lokal nicht — und lokal gebaute Pakete sollen sich nicht
# anders verhalten.
$altesBackend = Join-Path $flutterAusgabe 'backend'
if (Test-Path $altesBackend) {
    Write-Host "   (alten backend-Ordner aus der Flutter-Ausgabe entfernt)"
    Remove-Item $altesBackend -Recurse -Force
}

Copy-Item (Join-Path $flutterAusgabe '*') $ziel -Recurse -Force

# --- Dienst ---------------------------------------------------------------
# Nach dem Frontend, damit das Kopieren oben den Ordner nicht ueberschreibt.
Write-Host "-- Lokaler Dienst (self-contained)" -ForegroundColor Cyan
dotnet publish $backendProject `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    -p:Version=$Version `
    --output (Join-Path $ziel 'backend')
if ($LASTEXITCODE -ne 0) { throw "dotnet publish ist fehlgeschlagen." }

# --- Kontrolle ------------------------------------------------------------
# Fehlt eines dieser Stuecke, startet die Anwendung beim Anwender nicht bzw.
# zeigt eine leere Vorlagenliste. Das hier zu pruefen ist billiger, als es im
# Rauchtest oder gar beim Anwender zu bemerken.
$pflicht = @(
    'automation_app.exe',
    'backend/AutomationService.exe',
    'backend/appsettings.json'
)
foreach ($datei in $pflicht) {
    $pfad = Join-Path $ziel $datei
    if (-not (Test-Path $pfad)) { throw "Im Paket fehlt: $datei" }
}

$vorlagen = @(Get-ChildItem (Join-Path $ziel 'backend/Templates') -Filter *.docx -ErrorAction SilentlyContinue)
if ($vorlagen.Count -eq 0) {
    throw "Im Paket liegen keine Word-Vorlagen (backend/Templates/*.docx)."
}

$groesse = [math]::Round((Get-ChildItem $ziel -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
Write-Host "== Paket fertig: $ziel ($groesse MB, $($vorlagen.Count) Vorlagen) ==" -ForegroundColor Green
