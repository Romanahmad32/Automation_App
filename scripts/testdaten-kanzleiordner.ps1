<#
.SYNOPSIS
    Legt einen realistisch unordentlichen Akten-Stammordner zum Testen an.

.DESCRIPTION
    Der Zuordnungsstapel ist erst ab einigen hundert Ordnern das, was er in der
    Kanzlei ist: eine Menge, die von Hand nicht zu schaffen ist. Dieses Skript
    erzeugt sie — und zwar mit **Variationen**, nicht mit tausend Zeilen
    derselben Form:

      * Aktentyp-Praefixe in allen Schreibweisen aus `AktentypErkennung`,
        gewichtet nach dem, was in der Kanzlei wirklich haeufig ist. Die lange
        Form „Verkehrsunfallsache" ist bewusst selten.
      * Rund ein Drittel ganz **ohne** Praefix — genau die Ordner, die im
        Stapel liegenbleiben und die eigentliche Arbeit ausmachen.
      * Namensformen, an denen sich der Namensvorschlag reiben soll: nur
        Nachname, Vorname + Nachname, „Nachname, Vorname", Doppelnamen,
        Umlaute, Titel, Aktenzeichen, Eheleute, Datumszusaetze.
      * Ordner ohne Mandantenbezug (Buchhaltung, Vorlagen, Ablage …).
      * Einige Mandanten mit **zwei** Ordnern — der Fall, den der Import zu
        einem Eintrag zusammenfassen muss.

    Angelegt wird nur Neues: Vorhandene Ordner werden nie angefasst. Was das
    Skript erzeugt hat, steht in einer Merkliste im Stammordner
    (`.testdaten-manifest.txt`, eine Datei — der Akten-Scan liest nur Ordner
    und sieht sie deshalb nicht). `-Aufraeumen` loescht genau diese Ordner
    wieder und sonst nichts.

.PARAMETER Stammordner
    Der Akten-Stammordner. Ohne Angabe fragt das Skript den laufenden Dienst
    (`GET /api/Settings`) — dann trifft es genau den Ordner, den die App scannt.

.PARAMETER Anzahl
    Wie viele Akten-Ordner angelegt werden (Vorgabe 400).

.PARAMETER Seed
    Startwert des Zufalls. Gleicher Seed = gleiche Ordnernamen.

.PARAMETER Aufraeumen
    Loescht die zuvor angelegten Ordner (laut Merkliste) wieder.

.EXAMPLE
    ./scripts/testdaten-kanzleiordner.ps1 -Anzahl 600

.EXAMPLE
    ./scripts/testdaten-kanzleiordner.ps1 -Aufraeumen
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Stammordner,
    [int]$Anzahl = 400,
    [int]$Seed = 20260908,
    [switch]$Aufraeumen
)

$ErrorActionPreference = 'Stop'
$merklisteName = '.testdaten-manifest.txt'

function Get-StammordnerAusDienst {
    try {
        $settings = Invoke-RestMethod -Uri 'http://localhost:5143/api/Settings' -TimeoutSec 5
        return $settings.aktenStammordner
    } catch {
        return ''
    }
}

if (-not $Stammordner) {
    $Stammordner = Get-StammordnerAusDienst
    if (-not $Stammordner) {
        throw "Kein Stammordner: Dienst nicht erreichbar. Bitte -Stammordner angeben."
    }
    Write-Host "Stammordner aus den Einstellungen: $Stammordner"
}

if (-not (Test-Path $Stammordner)) {
    throw "Stammordner existiert nicht: $Stammordner"
}

$merkliste = Join-Path $Stammordner $merklisteName

# ---------------------------------------------------------------- Aufraeumen
if ($Aufraeumen) {
    if (-not (Test-Path $merkliste)) {
        Write-Host "Keine Merkliste gefunden — nichts anzuraeumen."
        return
    }
    $geloescht = 0
    foreach ($name in (Get-Content $merkliste -Encoding utf8)) {
        if (-not $name.Trim()) { continue }
        $pfad = Join-Path $Stammordner $name
        if (Test-Path $pfad) {
            if ($PSCmdlet.ShouldProcess($pfad, 'Loeschen')) {
                Remove-Item $pfad -Recurse -Force
                $geloescht++
            }
        }
    }
    if ($PSCmdlet.ShouldProcess($merkliste, 'Merkliste loeschen')) {
        Remove-Item $merkliste -Force
    }
    Write-Host "$geloescht Testordner entfernt."
    return
}

# ------------------------------------------------------------------ Bausteine
$rand = [Random]::new($Seed)
function Pick($liste) { $liste[$rand.Next(0, $liste.Count)] }
function Trifft([int]$prozent) { $rand.Next(0, 100) -lt $prozent }

$vornamen = @(
    'Anna', 'Jonas', 'Elif', 'Saeed', 'Mehmet', 'Laura', 'Tobias', 'Sophie',
    'Nina', 'Robert', 'Julia', 'Peter', 'Lukas', 'Ahmed', 'Mark', 'Bjoern',
    'Soeren', 'Juergen', 'Kai-Uwe', 'Marie-Luise', 'Hanna', 'Fatma', 'Dennis',
    'Katharina', 'Wolfgang', 'Ayse', 'Miriam', 'Sebastian', 'Ingrid', 'Yusuf'
)

$nachnamen = @(
    'Mueller', 'Müller', 'Schmidt', 'Schäfer', 'Groß', 'Weiß', 'Krüger',
    'Häberle', 'Öztürk', 'Yilmaz', 'Schmitz', 'Hoffmann', 'Bein', 'Wagner',
    'Becker', 'Fischer', 'Koch', 'Richter', 'Klein', 'Schulz', 'Ahmad',
    'Meier-Schulz', 'von Habsburg', 'de Vries', 'Baumgartner', 'Zimmermann',
    'Lehmann', 'Brandt', 'Kowalski', 'Nowak', 'Petrov', 'Dursun'
)

# Praefix und sein Anteil in Prozent. Summe der Anteile = 100.
# „Verkehrsunfallsache" steht bewusst weit unten: die Kanzlei schreibt fast
# immer eine der Kurzformen, und ein Testbestand, in dem jede zweite Zeile
# gleich aussieht, prueft die Erkennung nicht.
$praefixe = @(
    @{ Text = '';                     Anteil = 31 },
    @{ Text = 'VUnfallursache';       Anteil = 12 },
    @{ Text = 'VerkUnfursache';       Anteil = 7 },
    @{ Text = 'VUnvallursache';       Anteil = 5 },
    @{ Text = 'Verkehrsunfallsache';  Anteil = 4 },
    @{ Text = 'Owi';                  Anteil = 7 },
    @{ Text = 'Bußgeldsache';         Anteil = 6 },
    @{ Text = 'Bussgeldsache';        Anteil = 5 },
    @{ Text = 'BSsache';              Anteil = 4 },
    @{ Text = 'Strafsache';           Anteil = 6 },
    @{ Text = 'StrSache';             Anteil = 5 },
    @{ Text = 'FamSache';             Anteil = 5 },
    @{ Text = 'Familiensache';        Anteil = 3 }
)

$praefixTopf = foreach ($p in $praefixe) { for ($i = 0; $i -lt $p.Anteil; $i++) { $p.Text } }

$ohneBezug = @(
    'Buchhaltung 2019', 'Buchhaltung 2020', 'Buchhaltung 2021',
    'Buchhaltung 2022', 'Vorlagen', 'Muster', 'Ablage', 'Scans',
    '_Archiv alt', 'Fristenkalender', 'Kanzleiorganisation', 'Rundschreiben',
    'Fortbildung 2023', 'Zeiterfassung', 'Bilder Briefkopf', 'Postausgang'
)

$fallNamen = @(
    'Unfall v. 12.05.2019', 'Unfall v. 03.11.2021', 'Schriftverkehr',
    'Gutachten', 'Rechnungen', 'Korrespondenz 2021', 'Klage', 'Anhoerung',
    'Mandantenunterlagen', 'Fotos Unfallstelle'
)

# Namensformen — jede prueft etwas anderes am Namensvorschlag.
function Get-Namensform($vorname, $nachname) {
    switch ($rand.Next(0, 10)) {
        0 { $nachname }                                                   # nur Nachname (der Normalfall der Kanzlei)
        1 { "$vorname $nachname" }
        2 { "$nachname, $vorname" }                                       # Komma-Form: bleibt bewusst unaufgeloest
        3 { "$vorname $nachname TA$('{0:D3}' -f $rand.Next(100, 999))" }   # mit Aktenzeichen
        4 { "$nachname u. $(Pick $nachnamen)" }                           # Eheleute
        5 { "$vorname $nachname - Unfall $('{0:D2}' -f $rand.Next(1,29)).$('{0:D2}' -f $rand.Next(1,13)).$($rand.Next(2018,2026))" }
        6 { "Dr. $vorname $nachname" }
        7 { "$nachname $vorname" }                                        # umgedreht ohne Komma
        8 { "$nachname ($($rand.Next(2018, 2026)))" }
        default { "$vorname $nachname" }
    }
}

function Get-Ordnername {
    $vorname = Pick $vornamen
    $nachname = Pick $nachnamen
    $praefix = Pick $praefixTopf
    $kern = Get-Namensform $vorname $nachname
    if ($praefix) { "$praefix $kern" } else { $kern }
}

# ------------------------------------------------------------------- Anlegen
$vorhanden = @{}
foreach ($d in (Get-ChildItem $Stammordner -Directory)) { $vorhanden[$d.Name] = $true }

$neu = [System.Collections.Generic.List[string]]::new()
$versuche = 0
$maxVersuche = $Anzahl * 20

while ($neu.Count -lt $Anzahl -and $versuche -lt $maxVersuche) {
    $versuche++
    # Ordner ohne Mandantenbezug streuen sich unter die Akten (rund 4 %).
    $name = if (Trifft 4) { Pick $ohneBezug } else { Get-Ordnername }
    if ($vorhanden.ContainsKey($name)) { continue }
    $vorhanden[$name] = $true
    $neu.Add($name)

    # Jeder zwanzigste Mandant bekommt einen zweiten Ordner — der Fall, den
    # der Import zu EINEM Eintrag mit zwei Ordnernamen zusammenfassen muss.
    if ((Trifft 5) -and $neu.Count -lt $Anzahl) {
        $zweiter = "$name (2)"
        if (-not $vorhanden.ContainsKey($zweiter)) {
            $vorhanden[$zweiter] = $true
            $neu.Add($zweiter)
        }
    }
}

if ($neu.Count -lt $Anzahl) {
    Write-Warning "Nur $($neu.Count) von $Anzahl eindeutigen Namen gefunden — Namenstopf zu klein."
}

$angelegt = 0
foreach ($name in $neu) {
    $pfad = Join-Path $Stammordner $name
    if ($PSCmdlet.ShouldProcess($pfad, 'Anlegen')) {
        New-Item -ItemType Directory -Path $pfad -Force | Out-Null
        $angelegt++
        # Rund 40 % bekommen Fall-Unterordner — die App liest sie erst auf
        # Anforderung nach, und genau dieses Nachladen will man sehen.
        if (Trifft 40) {
            foreach ($fall in ($fallNamen | Get-Random -Count $rand.Next(1, 4))) {
                New-Item -ItemType Directory -Path (Join-Path $pfad $fall) -Force | Out-Null
            }
        }
    }
}

if ($PSCmdlet.ShouldProcess($merkliste, 'Merkliste schreiben')) {
    $bisher = if (Test-Path $merkliste) { Get-Content $merkliste -Encoding utf8 } else { @() }
    ($bisher + $neu) | Set-Content $merkliste -Encoding utf8
}

$gesamt = (Get-ChildItem $Stammordner -Directory).Count
Write-Host ""
Write-Host "$angelegt Ordner angelegt in $Stammordner"
Write-Host "Ordner im Stammordner jetzt: $gesamt"
Write-Host "Merkliste: $merkliste"
Write-Host "Zuruecknehmen: ./scripts/testdaten-kanzleiordner.ps1 -Aufraeumen"
