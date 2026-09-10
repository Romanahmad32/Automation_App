# Formatiert einmal je Sitzung die Dart-Dateien, die sich geaendert haben.
#
# Aufgerufen als Stop-Hook, also wenn der Agent seine Antwort beendet; die
# Nutzlast kommt als JSON auf stdin und wird nicht gebraucht.
#
# Warum Stop und nicht mehr PostToolUse auf Edit|Write: Der Matcher trifft nur
# das Werkzeug, nicht die Endung -- der Hook lief also auch bei jeder Markdown-,
# JSON- und YAML-Aenderung an. Gemessen kostete das 1,3 s je Nicht-Dart-
# Aenderung und 3,7 s je Dart-Aenderung; allein der Start von powershell.exe
# schlaegt mit rund 1,1 s zu Buche. Bei zwanzig Bearbeitungen in einer Sitzung
# sind das ueber vierzig Sekunden, die niemand sieht und die mit der Zahl der
# Bearbeitungen weiterwachsen.
#
# Hier faellt der Preis genau einmal je Sitzung an, und der Hook leistet dabei
# mehr als vorher: Er formatiert alles, was in der Sitzung entstanden ist, nicht
# nur die zuletzt geschriebene Datei. Verloren geht nur, dass eine Datei schon
# waehrend der Sitzung formatiert vorliegt -- dafuer, dass das je gefehlt haette,
# gibt es in der Historie keinen Beleg, und die CI prueft die Formatierung
# ohnehin (`dart format --set-exit-if-changed`).
#
# Der Hook schweigt in jedem Fehlerfall und endet mit 0. Ein Formatierer, der
# das Beenden einer Antwort anhaelt, kostet mehr als er einbringt.

$ErrorActionPreference = 'SilentlyContinue'

try {
    # Die Nutzlast wird nicht gebraucht, aber gelesen: stdin ungelesen stehen
    # zu lassen, kann den Aufrufer beim Schreiben blockieren.
    [void][Console]::In.ReadToEnd()

    $wurzel = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $frontend = Join-Path $wurzel 'Automation_App_Frontend'
    if (-not (Test-Path -LiteralPath $frontend)) { exit 0 }

    # Aus der Repo-Wurzel gefragt, damit die Pfade repo-relativ zurueckkommen
    # und die Frontend-Grenze im Pfad selbst steht. `-c core.quotepath=false`:
    # sonst schreibt Git Umlaute als Oktal-Escapes, und der Pfad ist danach
    # nicht mehr auffindbar.
    $zeilen = & git -C $wurzel -c core.quotepath=false status --porcelain 2>$null
    if (-not $zeilen) { exit 0 }

    $dateien = @()
    foreach ($zeile in $zeilen) {
        if ($zeile.Length -lt 4) { continue }
        # Die zwei Statusspalten und das trennende Leerzeichen abschneiden.
        $pfad = $zeile.Substring(3)
        # Umbenennung steht als "alt -> neu" da; formatiert wird der neue Name,
        # den alten gibt es nicht mehr.
        $pfeil = $pfad.IndexOf(' -> ')
        if ($pfeil -ge 0) { $pfad = $pfad.Substring($pfeil + 4) }
        $pfad = $pfad.Trim('"')

        if ($pfad -notlike 'Automation_App_Frontend/*') { continue }
        if ($pfad -notlike '*.dart') { continue }

        # Generierte Dateien nicht anfassen: was build_runner erzeugt, muss
        # byte-gleich zu einem frischen Lauf bleiben, sonst meldet die
        # CI-Pruefung auf aktuelle Generate-Ausgaben einen Unterschied, den
        # niemand geschrieben hat.
        $generiert = $false
        foreach ($endung in '.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart') {
            if ($pfad.EndsWith($endung)) { $generiert = $true }
        }
        if ($generiert) { continue }

        # Geloeschte Dateien stehen im Status wie geaenderte; sie fallen hier
        # heraus, statt `dart format` mit einem Fehler zu beantworten.
        $voll = Join-Path $wurzel $pfad
        if (Test-Path -LiteralPath $voll) { $dateien += $voll }
    }
    if ($dateien.Count -eq 0) { exit 0 }

    # Das projektlokale FVM-SDK bevorzugen (fvm use, siehe docs/RELEASE.md):
    # der Hook formatiert dann mit derselben dart-Fassung wie Pruefkette und
    # CI. Ohne .fvm/ gilt wie bisher das dart aus dem PATH.
    $dart = Join-Path $frontend '.fvm\flutter_sdk\bin\dart.bat'
    if (-not (Test-Path -LiteralPath $dart)) { $dart = 'dart' }

    # Ein Aufruf fuer alle Dateien, nicht einer je Datei: teuer ist der Start
    # des SDK, nicht das Formatieren.
    & $dart format @dateien | Out-Null
}
catch {
    # bewusst leer, siehe Kopf
}

exit 0
