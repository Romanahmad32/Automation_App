<#
.SYNOPSIS
    Kleiner Ersatz für GitHubs `releases/latest`, damit der Update-Weg der App
    mit einer Testversion abgenommen werden kann (Issue #199).

.DESCRIPTION
    Der Dienst fragt die Adresse aus `Aktualisierung__Quelle` ab und lädt die
    Setup-Datei, die in der Antwort steht. Dieser Server liefert beides für eine
    übergebene Setup-Datei -- im Format der GitHub-Antwort (`tag_name`, `assets`
    mit `name`, `size`, `digest`, `browser_download_url`):

      GET /repos/Romanahmad32/Automation_App/releases/latest   -> JSON
      GET /download/Automation_App_Setup_<version>.exe         -> die Datei

    Die Version ergibt sich aus dem Dateinamen (Automation_App_Setup_1.2.99.exe).
    Als Quelle gehört `http://localhost:8765/repos/Romanahmad32/Automation_App/releases/latest`
    in `Aktualisierung__Quelle`; das erledigt `vorbereiten.ps1`.

    -Fall steuert, was schiefgeht (der Fall gilt für die ganze Laufzeit des Servers):
      normal          alles in Ordnung
      ohneDigest      die Antwort trägt kein `digest`  -> der Dienst lädt nicht
      falscherDigest  `digest` stimmt nicht            -> Prüfung schlägt nach dem Download an
      abbruch         die Verbindung wird mitten im Download geschlossen
      403             `releases/latest` antwortet schlicht 403, ohne Köpfe (wie ein
                      sperrender Kanzlei-Proxy)  -> Meldung "keine Verbindung"
      403limit         403 mit `X-RateLimit-Remaining: 0` (GitHubs Ratenlimit)
                                                 -> Meldung "Update-Server ausgelastet"
      429             `releases/latest` antwortet 429 (ebenfalls Ratenlimit)

    Beenden mit Strg+C. -Selbsttest startet den Server, fragt ihn einmal selbst ab
    (Antwort und Download, Prüfsumme verglichen) und endet; ohne Hintergrundprozess.

.EXAMPLE
    ./scripts/update-abnahme/ersatzserver.ps1 -Setup C:\Abnahme\Automation_App_Setup_1.2.99.exe
    ./scripts/update-abnahme/ersatzserver.ps1 -Setup ...\Automation_App_Setup_1.2.99.exe -Fall abbruch
    ./scripts/update-abnahme/ersatzserver.ps1 -Selbsttest
#>
param(
    [string]$Setup,
    [ValidateSet('normal', 'ohneDigest', 'falscherDigest', 'abbruch', '403', '403limit', '429')]
    [string]$Fall = 'normal',
    [int]$Port = 8765,
    [switch]$Selbsttest
)

$ErrorActionPreference = 'Stop'
$basis = "http://localhost:$Port"
$apiPfad = '/repos/Romanahmad32/Automation_App/releases/latest'

function Get-Sha256([string]$pfad) {
    (Get-FileHash -LiteralPath $pfad -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Send-Text($ctx, [int]$status, [string]$text, [string]$typ) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    $ctx.Response.StatusCode = $status
    $ctx.Response.ContentType = $typ
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
}

# Die GitHub-förmige Antwort für die Setup-Datei, mit den Abweichungen des Falls.
function New-ReleaseJson([string]$pfad, [string]$version, [string]$fall) {
    $name = Split-Path -Leaf $pfad
    $digest = 'sha256:' + (Get-Sha256 $pfad)
    if ($fall -eq 'falscherDigest') {
        # Erste Hex-Ziffer vertauschen: gültiges Format, falscher Inhalt.
        $erste = if ($digest[7] -eq '0') { '1' } else { '0' }
        $digest = $digest.Substring(0, 7) + $erste + $digest.Substring(8)
    }
    $asset = [ordered]@{
        name                 = $name
        size                 = (Get-Item -LiteralPath $pfad).Length
        content_type         = 'application/x-msdownload'
        browser_download_url = "$basis/download/$name"
    }
    if ($fall -ne 'ohneDigest') { $asset['digest'] = $digest }
    [ordered]@{ tag_name = "v$version"; assets = @($asset) } | ConvertTo-Json -Depth 5
}

# Schickt die Datei in Stücken. Im Fall `abbruch` nach der Hälfte: Die Antwort
# hat die volle Länge angekündigt, der Server schließt die Verbindung hart.
function Send-Datei($ctx, [string]$pfad, [string]$fall) {
    $laenge = (Get-Item -LiteralPath $pfad).Length
    $ctx.Response.ContentType = 'application/octet-stream'
    $ctx.Response.ContentLength64 = $laenge
    $quelle = [IO.File]::OpenRead($pfad)
    try {
        $puffer = New-Object byte[] (1MB)
        $gesendet = 0L
        while (($n = $quelle.Read($puffer, 0, $puffer.Length)) -gt 0) {
            $ctx.Response.OutputStream.Write($puffer, 0, $n)
            $gesendet += $n
            if ($fall -eq 'abbruch') {
                Start-Sleep -Milliseconds 100   # damit der Fortschritt sichtbar wird
                if ($gesendet -ge $laenge / 2) {
                    $ctx.Response.Abort()
                    return "abgebrochen nach $gesendet von $laenge Bytes"
                }
            }
        }
        $ctx.Response.Close()
        return "gesendet, $laenge Bytes"
    }
    finally { $quelle.Dispose() }
}

function Invoke-Anfrage($ctx, [string]$pfad, [string]$version, [string]$fall) {
    $url = $ctx.Request.Url.AbsolutePath
    if ($url -eq $apiPfad) {
        if ($fall -in '403', '403limit', '429') {
            $status = [int]($fall -replace 'limit', '')
            if ($fall -eq '403limit') {
                $ctx.Response.Headers.Add('X-RateLimit-Remaining', '0')
            }
            Send-Text $ctx $status '{"message":"Ersatzserver: absichtlich abgewiesen"}' 'application/json'
            return "Status $status ($fall)"
        }
        Send-Text $ctx 200 (New-ReleaseJson $pfad $version $fall) 'application/json'
        return "releases/latest, Fall $fall"
    }
    if ($url -eq "/download/$(Split-Path -Leaf $pfad)") {
        return Send-Datei $ctx $pfad $fall
    }
    Send-Text $ctx 404 '{"message":"Not Found"}' 'application/json'
    return 'Status 404'
}

function Start-Ersatzserver([string]$pfad, [string]$fall, [int]$anzahl) {
    if ((Split-Path -Leaf $pfad) -notmatch '^Automation_App_Setup_(\d+\.\d+\.\d+)\.exe$') {
        throw "Der Dateiname muss Automation_App_Setup_<x.y.z>.exe lauten (der Dienst nimmt nur diesen): $pfad"
    }
    $version = $Matches[1]
    $listener = New-Object Net.HttpListener
    $listener.Prefixes.Add("$basis/")
    $listener.Start()
    Write-Host "Ersatzserver läuft: $basis$apiPfad"
    Write-Host "  Setup $version, Fall '$fall'. Beenden mit Strg+C." -ForegroundColor Cyan
    try {
        $bedient = 0
        while ($anzahl -eq 0 -or $bedient -lt $anzahl) {
            # In kurzen Abschnitten warten, damit Strg+C ankommt.
            $aufgabe = $listener.GetContextAsync()
            while (-not $aufgabe.AsyncWaitHandle.WaitOne(300)) { }
            $ctx = $aufgabe.Result
            $ergebnis = Invoke-Anfrage $ctx $pfad $version $fall
            Write-Host ("{0:HH:mm:ss}  {1} {2}  ->  {3}" -f (Get-Date), $ctx.Request.HttpMethod, $ctx.Request.Url.AbsolutePath, $ergebnis)
            $bedient++
        }
    }
    finally {
        $listener.Stop()
        $listener.Close()
        Write-Host 'Ersatzserver beendet.'
    }
}

if ($Selbsttest) {
    Add-Type -AssemblyName System.Net.Http
    $ordner = Join-Path ([IO.Path]::GetTempPath()) "ersatzserver-selbsttest-$PID"
    New-Item -ItemType Directory -Path $ordner | Out-Null
    $datei = Join-Path $ordner 'Automation_App_Setup_9.9.9.exe'
    [IO.File]::WriteAllBytes($datei, (1..4096 | ForEach-Object { $_ % 251 }) -as [byte[]])
    $client = New-Object Net.Http.HttpClient
    try {
        # Die Abfrage läuft als Task, der Server bedient sie im selben Prozess.
        $antwort = $client.GetStringAsync("$basis$apiPfad")
        $json = $null
        $listener = New-Object Net.HttpListener
        $listener.Prefixes.Add("$basis/")
        $listener.Start()
        try {
            $ctx = $listener.GetContext()
            Send-Text $ctx 200 (New-ReleaseJson $datei '9.9.9' 'normal') 'application/json'
            $json = $antwort.Result | ConvertFrom-Json
            $asset = $json.assets[0]

            $laden = $client.GetByteArrayAsync($asset.browser_download_url)
            $ctx = $listener.GetContext()
            $null = Send-Datei $ctx $datei 'normal'
            $bytes = $laden.Result
        }
        finally { $listener.Stop(); $listener.Close() }

        $hash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
        $fehler = @()
        if ($json.tag_name -ne 'v9.9.9') { $fehler += "tag_name: $($json.tag_name)" }
        if ($asset.name -ne 'Automation_App_Setup_9.9.9.exe') { $fehler += "name: $($asset.name)" }
        if ($asset.size -ne 4096) { $fehler += "size: $($asset.size)" }
        if ($asset.digest -ne "sha256:$hash") { $fehler += "digest $($asset.digest) passt nicht zum Download ($hash)" }
        if ($fehler) { throw "Selbsttest fehlgeschlagen:`n  $($fehler -join "`n  ")" }
        # Die zwei 403-Fälle unterscheiden sich im Kopf X-RateLimit-Remaining.
        foreach ($fall in '403', '403limit') {
            $abfrage = $client.GetAsync("$basis$apiPfad")
            $listener = New-Object Net.HttpListener
            $listener.Prefixes.Add("$basis/")
            $listener.Start()
            try {
                $null = Invoke-Anfrage ($listener.GetContext()) $datei '9.9.9' $fall
                $r = $abfrage.Result
            }
            finally { $listener.Stop(); $listener.Close() }
            $hatKopf = $r.Headers.Contains('X-RateLimit-Remaining')
            if ([int]$r.StatusCode -ne 403 -or $hatKopf -ne ($fall -eq '403limit')) {
                throw "Selbsttest fehlgeschlagen: Fall $fall -> Status $([int]$r.StatusCode), Kopf vorhanden: $hatKopf"
            }
        }
        Write-Host 'Selbsttest ok: Antwort im GitHub-Format, Download und digest stimmen überein; 403 und 403limit unterscheiden sich im Kopf.' -ForegroundColor Green
    }
    finally {
        $client.Dispose()
        Remove-Item -LiteralPath $ordner -Recurse -Force -ErrorAction SilentlyContinue
    }
    return
}

if (-not $Setup) { throw 'Bitte -Setup <Pfad zur Automation_App_Setup_x.y.z.exe> angeben (oder -Selbsttest).' }
if (-not (Test-Path -LiteralPath $Setup)) { throw "Setup-Datei nicht gefunden: $Setup" }
Start-Ersatzserver (Resolve-Path -LiteralPath $Setup).Path $Fall 0
