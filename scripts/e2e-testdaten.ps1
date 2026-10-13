<#
.SYNOPSIS
    Legt den Ausgangsbestand fuer einen E2E-Lauf im Testmodus an.

.DESCRIPTION
    Eine frische Testmodus-Datenbank ist leer: keine Kanzlei, kein Postfach-
    Zugang, keine Mandanten, keine Formularvorlage. Ohne diesen Bestand kann
    ein E2E-Lauf weder einen Vorgang starten noch das Anspruchsschreiben fuellen
    noch den Versand-Dialog oeffnen (der verlangt einen Postfach-Zugang).

    Angelegt wird ueber die REST-Schnittstelle des laufenden Dienstes -- genau
    der Weg, den die Oberflaeche nimmt, also ohne Abkuerzung an der Datenbank.

    **Sicherheitsschranke:** Zuerst wird GET /health gelesen. Meldet der Dienst
    `testmodus` nicht ausdruecklich als `true`, bricht das Skript ab, BEVOR es
    ein einziges Mal schreibt. Der Port allein beweist nichts: Auf 5143 laeuft
    womoeglich die echte App mit dem echten Bestand der Kanzlei.

    Alles ist erfunden: fiktive Namen, Adressen auf `.invalid` (RFC 2606, loest
    nie auf), keine Bank- oder Steuerdaten. Der Postfach-Zugang ist ausgeschaltet
    (`enabled=false`) und zeigt auf einen Host, den es nicht gibt -- im
    Testmodus darf NIE ein echter Zugang eingetragen werden.

.PARAMETER Port
    Port des Testmodus-Dienstes (Vorgabe 5243, Umgebung `E2E`).

.PARAMETER Wurzel
    E2E-Wurzelordner (`%TEMP%\automation-e2e\<zeit>`). Darunter entstehen
    `akten\` (Aktenstammordner) und `register\`; `dienst\` und `daten\` kennt
    e2e-start.ps1. Pflicht.

.PARAMETER MitVorgang
    Legt zusaetzlich einen Vorgang im Status "angefragt" zum ersten Mandanten an.

.EXAMPLE
    ./scripts/e2e-testdaten.ps1 -Wurzel $env:TEMP\automation-e2e\manuell
#>
[CmdletBinding()]
param(
    [ValidateScript({
        if ($_ -eq 5143) { throw 'Port 5143 ist der Port der installierten App und fuer den Testmodus gesperrt.' }
        $true
    })]
    [int]$Port = 5243,

    [Parameter(Mandatory = $true)]
    [string]$Wurzel,

    [switch]$MitVorgang
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$basis = "http://localhost:$Port"
$wurzel = [System.IO.Path]::GetFullPath($Wurzel)

function Sende-Json([string]$Methode, [string]$Pfad, $Inhalt) {
    # Als UTF-8-Bytes senden: PowerShell 5.1 nimmt sonst die ANSI-Codepage.
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Inhalt | ConvertTo-Json -Depth 10 -Compress))
    Invoke-RestMethod -Method $Methode -Uri "$basis$Pfad" -Body $bytes `
        -ContentType 'application/json; charset=utf-8' -TimeoutSec 60
}

# --- Schranke: nur gegen einen Testmodus-Dienst schreiben ------------------
try {
    $gesundheit = Invoke-RestMethod "$basis/health" -TimeoutSec 10
}
catch {
    throw "Kein Dienst unter $basis erreichbar. Zuerst scripts/e2e-start.ps1 starten. ($($_.Exception.Message))"
}
$testmodus = $gesundheit.PSObject.Properties['testmodus']
if ($null -eq $testmodus -or $testmodus.Value -ne $true) {
    throw "Der Dienst unter $basis meldet keinen Testmodus (testmodus != true). " +
          "Es wurde NICHTS geschrieben -- das waere womoeglich der echte Bestand."
}
Write-Host "== Ausgangsbestand fuer $basis (Testmodus) ==" -ForegroundColor Cyan

# --- Ordner ----------------------------------------------------------------
$akten = Join-Path $wurzel 'akten'
$register = Join-Path $wurzel 'register'
New-Item -ItemType Directory -Path $akten, $register -Force | Out-Null

# --- Einstellungen: vorhandene holen, nur das Noetige ueberschreiben --------
$einstellungen = Invoke-RestMethod "$basis/api/Settings" -TimeoutSec 30
$einstellungen.name = 'Kanzlei Mustermann (Testmodus)'
$einstellungen.strasseHausnummer = 'Musterweg 1'
$einstellungen.postleitzahl = '12345'
$einstellungen.ort = 'Musterstadt'
$einstellungen.emailAdresse = 'kanzlei@testmodus.invalid'
$einstellungen.telefonnummer = '000 000000'
$einstellungen.aktenStammordner = $akten
$einstellungen.registerAblageOrdner = $register
Sende-Json 'PUT' '/api/Settings' $einstellungen | Out-Null
Write-Host "Einstellungen: Aktenstamm $akten"

# --- Postfach-Zugang (ausgeschaltet, Host loest nie auf) -------------------
Sende-Json 'PUT' '/api/Mailbox/config' ([ordered]@{
        enabled       = $false
        authMethod    = 'AppPassword'
        host          = 'imap.testmodus.invalid'
        port          = 993
        useSsl        = $true
        username      = 'kanzlei@testmodus.invalid'
        appPassword   = 'testmodus'
        folder        = 'INBOX'
        subjectFilter = 'Zentralruf'
    }) | Out-Null
Write-Host 'Postfach-Zugang: imap.testmodus.invalid (aus)'

# --- Mandanten mit Aktenordner ---------------------------------------------
$mandanten = @(
    @{ anrede = 'herr'; vorname = 'Max'; nachname = 'Mustermann'; kennzeichen = 'HG-E 1427' },
    @{ anrede = 'frau'; vorname = 'Erika'; nachname = 'Beispiel'; kennzeichen = 'F-XY 99' }
)
$mandantIds = @()
foreach ($m in $mandanten) {
    $ordnerName = "VUnfallursache $($m.nachname)"
    New-Item -ItemType Directory -Path (Join-Path $akten $ordnerName) -Force | Out-Null
    $angelegt = Sende-Json 'POST' '/api/Mandanten' ([ordered]@{
            anrede                = $m.anrede
            vorname               = $m.vorname
            nachname              = $m.nachname
            strasseHausnummer     = 'Testgasse 7'
            postleitzahl          = '54321'
            ort                   = 'Beispielhausen'
            emailAdresse          = "$($m.nachname.ToLower())@testmodus.invalid"
            telefonnummer         = '000 111111'
            notiz                 = 'E2E-Testmodus'
            persoenlicheGrussformel = ''
            aktenOrdnernamen      = @($ordnerName)
            kennzeichen           = @($m.kennzeichen)
        })
    $mandantIds += $angelegt.id
    Write-Host "Mandant $($angelegt.id): $($m.vorname) $($m.nachname) ($ordnerName)"
}

# --- Formularvorlage aus dem mitgelieferten Muster -------------------------
# Das Muster liegt nach dem Start im (umgelenkten) Vorlagenordner; sonst im
# Build-Ausgabeordner des Dienstes.
$muster = 'Muster_Anspruchsschreiben_ohne_Auflistung.docx'
$kandidaten = @()
$kandidaten += Get-ChildItem (Join-Path $wurzel 'daten') -Recurse -Filter $muster -ErrorAction SilentlyContinue
$kandidaten += Get-ChildItem (Join-Path $wurzel 'dienst\Templates') -Filter $muster -ErrorAction SilentlyContinue
if ($kandidaten.Count -eq 0) { throw "Vorlage $muster weder im Datenordner noch im Dienstordner gefunden." }
$vorlage = $kandidaten[0].FullName

$platzhalter = Sende-Json 'POST' '/api/WordAutomation/template-placeholders' @{ templateFilePath = $vorlage }
$felder = @()
$reihenfolge = 1
foreach ($name in @($platzhalter.placeholders)) {
    $felder += [ordered]@{
        order     = $reihenfolge++
        label     = [string]$name
        required  = $true
        inputType = 'text'
    }
}
$vorlagenAntwort = Sende-Json 'POST' '/api/FormTemplates' ([ordered]@{
        templateName              = 'Testmodus Anspruchsschreiben'
        fields                    = $felder
        wordFilePathOhneAuflistung = $vorlage
        wordFilePathMitAuflistung  = $null
    })
Write-Host "Formularvorlage $($vorlagenAntwort.id): $($felder.Count) Felder aus $muster"

# --- Optional: ein Vorgang --------------------------------------------------
if ($MitVorgang) {
    $referenz = 'E2E-0001'
    Sende-Json 'PUT' '/api/Vorgaenge' ([ordered]@{
            referenz              = $referenz
            angefragtAm           = (Get-Date).ToUniversalTime().ToString('o')
            status                = 'angefragt'
            rechtsgebiet          = 'Verkehrsrecht'
            laufendeNummer        = $null
            jahr                  = $null
            abteilung             = $null
            kennzeichen           = $mandanten[0].kennzeichen
            mandantId             = $mandantIds[0]
            mandantName           = "$($mandanten[0].vorname) $($mandanten[0].nachname)"
            gegner                = $null
            unfallDatum           = $null
            geschaedigtenKennzeichen = $null
            unfallort             = $null
            unfalluhrzeit         = $null
            polizeiVorgangsnummer = $null
            antwort               = $null
            feldWerte             = $null
            schadensaufstellung   = $null
            entwurf               = $null
            schreibenNummer       = $null
            dokumentPfad          = $null
            aktenOrdner           = $null
            abgeschlossenAm       = $null
        }) | Out-Null
    Write-Host "Vorgang: $referenz (angefragt)"
}

Write-Host "== Ausgangsbestand angelegt: Mandanten $($mandantIds -join ', '), Vorlage $($vorlagenAntwort.id) ==" -ForegroundColor Green
