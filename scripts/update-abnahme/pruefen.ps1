<#
.SYNOPSIS
    Zeigt den Zustand der Installation nach jedem Schritt der Update-Abnahme
    (Issue #199). Nur lesend: ändert nichts, startet nichts, beendet nichts.

.DESCRIPTION
    Zeigt: installierte Version, laufende Prozesse der App, `/health` des
    Dienstes, Installer-Protokoll und Merkdatei der Aktualisierung, die
    Sicherungen vor einer Datenbank-Umstellung und die gesetzte Quelle.

.EXAMPLE
    ./scripts/update-abnahme/pruefen.ps1
#>
param(
    [int]$DienstPort = 5143
)

$ErrorActionPreference = 'Continue'

function Write-Kopf([string]$text) { Write-Host "`n== $text" -ForegroundColor Cyan }

Write-Kopf 'Installierte Version'
# AppId aus installer/setup.iss; je Benutzer installiert, also HKCU. Inno hängt "_is1" an.
$schluessel = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{2688470D-4684-412B-A385-A0B658CD2940}_is1'
$eintrag = Get-ItemProperty -Path $schluessel -ErrorAction SilentlyContinue
if ($eintrag) {
    Write-Host "  DisplayVersion: $($eintrag.DisplayVersion)"
    Write-Host "  Ordner:         $($eintrag.InstallLocation)"
} else {
    Write-Host '  nicht installiert (kein Deinstallationseintrag)'
}

Write-Kopf 'Laufende Prozesse'
$prozesse = @(Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -in 'automation_app', 'AutomationService' -or $_.ProcessName -like 'Automation_App_Setup*' })
if ($prozesse) {
    $prozesse | ForEach-Object { Write-Host ("  {0,-28} PID {1}  seit {2:HH:mm:ss}" -f $_.ProcessName, $_.Id, $_.StartTime) }
} else {
    Write-Host '  keine (App, Dienst und Setup laufen nicht)'
}

Write-Kopf "Dienst /health (Port $DienstPort)"
try {
    $health = Invoke-RestMethod -Uri "http://localhost:$DienstPort/health" -TimeoutSec 3
    Write-Host "  $($health | ConvertTo-Json -Compress)"
} catch {
    Write-Host "  keine Antwort ($($_.Exception.Message))"
}

Write-Kopf 'Aktualisierung (Protokoll und Merkdatei)'
$ordner = Join-Path $env:LOCALAPPDATA 'AutomationService\Aktualisierung'
if (Test-Path $ordner) {
    Get-ChildItem -LiteralPath $ordner -File | Sort-Object LastWriteTime | ForEach-Object {
        Write-Host ("  {0,-42} {1,12:N0} Bytes  {2:dd.MM. HH:mm:ss}" -f $_.Name, $_.Length, $_.LastWriteTime)
    }
    $merk = Join-Path $ordner 'letzte-aktualisierung.json'
    if (Test-Path $merk) { Write-Host "  Merkdatei: $(Get-Content -LiteralPath $merk -Raw)" }
    else { Write-Host '  Merkdatei: keine' }
    $logs = Get-ChildItem -LiteralPath $ordner -Filter 'installer-*.log' -File | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($logs) {
        Write-Host "  Letzte Zeilen von $($logs.Name):"
        Get-Content -LiteralPath $logs.FullName -Tail 8 | ForEach-Object { Write-Host "    $_" }
    }
} else {
    Write-Host "  Ordner fehlt: $ordner"
}

Write-Kopf 'Sicherungen vor Datenbank-Umstellung'
$sicherungen = @(Get-ChildItem -Path (Join-Path $env:APPDATA 'AutomationService\Sicherungen') -Filter 'automation-vor-migration-*.db' -ErrorAction SilentlyContinue)
if ($sicherungen) {
    $sicherungen | ForEach-Object { Write-Host ("  {0}  {1:N0} Bytes" -f $_.Name, $_.Length) }
} else {
    Write-Host '  keine'
}

Write-Kopf 'Update-Quelle'
$quelle = [Environment]::GetEnvironmentVariable('Aktualisierung__Quelle', 'User')
Write-Host ("  Aktualisierung__Quelle (Benutzer): " + $(if ($quelle) { $quelle } else { 'nicht gesetzt (GitHub)' }))
