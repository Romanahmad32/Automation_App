<#
.SYNOPSIS
    Richtet einen Test-PC für die Update-Abnahme ein und lenkt die Update-Quelle
    der App auf den Ersatzserver um (Issue #199) -- oder stellt sie zurück.

.DESCRIPTION
    Drei Aufrufe, in dieser Reihenfolge:

      -Einrichten      EINMAL, vor der Installation von 1.2.0: prüft, dass es auf
                       diesem Rechner weder eine installierte App noch eine
                       Datenbank unter %APPDATA%\AutomationService gibt, und legt
                       dann eine Markerdatei an (%LOCALAPPDATA%\AutomationService-Abnahme\
                       testrechner.txt, mit Datum und Benutzer). Sie sagt: Dieser
                       Rechner ist ein Test-PC, die Datenbank dort ist die der Abnahme.
      (ohne Schalter)  setzt die Benutzer-Umgebungsvariable `Aktualisierung__Quelle`
                       auf den Ersatzserver. Der Dienst liest sie beim Start; sie erbt
                       sich App -> Dienst -> Setup -> neu gestartete App. Die App muss
                       danach neu gestartet werden.
      -Zuruecksetzen   entfernt die Variable wieder (der Marker bleibt);
                       -MarkerEntfernen löscht den Marker (allein oder zusammen mit -Zuruecksetzen).

    Der Schutz gegen einen Rechner mit echten Daten: Liegt eine Datenbank, und es
    gibt keinen Marker, bricht jeder Aufruf außer -Zuruecksetzen ab. Der Marker
    entsteht nur, wenn VOR der Installation nichts da war. -Erzwingen ist der
    Notausgang und warnt deutlich.

.EXAMPLE
    ./scripts/update-abnahme/vorbereiten.ps1 -Einrichten
    ./scripts/update-abnahme/vorbereiten.ps1
    ./scripts/update-abnahme/vorbereiten.ps1 -Zuruecksetzen
#>
param(
    [int]$Port = 8765,
    [switch]$Einrichten,
    [switch]$Zuruecksetzen,
    [switch]$MarkerEntfernen,
    [switch]$Erzwingen
)

$ErrorActionPreference = 'Stop'
$name = 'Aktualisierung__Quelle'
$quelle = "http://localhost:$Port/repos/Romanahmad32/Automation_App/releases/latest"
$markerOrdner = Join-Path $env:LOCALAPPDATA 'AutomationService-Abnahme'
$marker = Join-Path $markerOrdner 'testrechner.txt'
$daten = Join-Path $env:APPDATA 'AutomationService'
$datenbanken = @(Get-ChildItem -LiteralPath $daten -Filter '*.db' -File -ErrorAction SilentlyContinue)

function Remove-Marker {
    if (Test-Path -LiteralPath $marker) {
        Remove-Item -LiteralPath $marker -Force
        Write-Host 'Marker entfernt: Der Rechner gilt nicht mehr als Test-PC.' -ForegroundColor Green
    } else {
        Write-Host 'Kein Marker vorhanden.'
    }
}

if ($Zuruecksetzen) {
    [Environment]::SetEnvironmentVariable($name, $null, 'User')
    Write-Host "$name entfernt. Die App danach neu starten, dann gilt wieder GitHub." -ForegroundColor Green
    if ($MarkerEntfernen) { Remove-Marker }
    return
}

# -MarkerEntfernen allein: nur den Marker entfernen, die Variable bleibt.
if ($MarkerEntfernen) {
    Remove-Marker
    return
}

if ($Einrichten) {
    # Eine installierte App (Inno-Eintrag, AppId aus installer/setup.iss) oder eine
    # Datenbank vor der ersten Installation heißt: Hier arbeitet jemand.
    $schluessel = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{2688470D-4684-412B-A385-A0B658CD2940}_is1'
    $installiert = Test-Path $schluessel
    if (($installiert -or $datenbanken.Count -gt 0) -and -not $Erzwingen) {
        throw "Hier ist schon etwas: App installiert = $installiert, Datenbanken unter $daten = $($datenbanken.Count). Das sieht nach einem Rechner mit echten Daten aus. Abbruch. Ein frischer Test-PC hat beides nicht; wer sicher ist: -Erzwingen."
    }
    if ($installiert -or $datenbanken.Count -gt 0) {
        Write-Warning "ACHTUNG: -Erzwingen auf einem Rechner mit App oder Datenbank. Die Abnahme installiert Versionen darüber und stellt Fehlerfälle nach -- Daten können umgestellt oder verändert werden."
    }
    New-Item -ItemType Directory -Force -Path $markerOrdner | Out-Null
    "Test-PC fuer die Update-Abnahme (#199), eingerichtet $(Get-Date -Format 'yyyy-MM-dd HH:mm') von $env:USERNAME auf $env:COMPUTERNAME" |
        Set-Content -LiteralPath $marker -Encoding UTF8
    Write-Host "Marker angelegt: $marker" -ForegroundColor Green
    Write-Host 'Jetzt 1.2.0 installieren. Danach ohne Schalter erneut aufrufen, wenn es an Weg B geht.'
    return
}

# Umlenken: Liegt eine Datenbank, muss der Marker beweisen, dass es die der Abnahme ist.
if ($datenbanken.Count -gt 0 -and -not (Test-Path -LiteralPath $marker)) {
    if (-not $Erzwingen) {
        throw "Unter $daten liegt eine Datenbank ($($datenbanken[0].Name)), aber dieser Rechner ist nicht als Test-PC eingerichtet (kein Marker $marker). Das sieht nach einem Rechner mit echten Daten aus. Abbruch. Auf einem frischen Test-PC läuft vor der Installation von 1.2.0 zuerst -Einrichten; wer sicher ist: -Erzwingen."
    }
    Write-Warning "ACHTUNG: -Erzwingen auf einem Rechner mit Datenbank ($daten) ohne Marker. Die Abnahme fährt Updates und Fehlerfälle über diese App -- Daten können umgestellt oder verändert werden."
}

[Environment]::SetEnvironmentVariable($name, $quelle, 'User')
Write-Host "$name gesetzt:" -ForegroundColor Green
Write-Host "  $quelle"
Write-Host 'Die App jetzt (neu) starten -- ein schon laufender Dienst kennt den Wert noch nicht.'
Write-Host 'Danach ./scripts/update-abnahme/ersatzserver.ps1 -Setup <Setup-Datei> in einem eigenen Fenster laufen lassen.'
