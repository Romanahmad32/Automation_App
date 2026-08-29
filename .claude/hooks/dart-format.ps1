# Formatiert die gerade geschriebene Dart-Datei.
#
# Aufgerufen als PostToolUse-Hook nach Edit/Write; die Nutzlast kommt als JSON
# auf stdin. Warum ein Skript und kein Einzeiler in settings.json: auf diesem
# Rechner gibt es weder jq noch pwsh, und powershell.exe ist das Einzige, das
# auf jedem Windows-Rechner sicher vorhanden ist.
#
# Der Hook schweigt in jedem Fehlerfall und endet mit 0. Ein Formatierer, der
# eine Werkzeugausfuehrung abbricht, kostet mehr als er einbringt.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $roh = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($roh)) { exit 0 }

    $eingabe = $roh | ConvertFrom-Json
    $pfad = $eingabe.tool_response.filePath
    if (-not $pfad) { $pfad = $eingabe.tool_input.file_path }
    if (-not $pfad) { exit 0 }

    if ($pfad -notlike '*.dart') { exit 0 }

    # Generierte Dateien nicht anfassen: was build_runner erzeugt, muss byte-
    # gleich zu einem frischen Lauf bleiben, sonst meldet die CI-Pruefung auf
    # aktuelle Generate-Ausgaben einen Unterschied, den niemand geschrieben hat.
    foreach ($endung in '.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart') {
        if ($pfad.EndsWith($endung)) { exit 0 }
    }

    if (-not (Test-Path -LiteralPath $pfad)) { exit 0 }

    # Das projektlokale FVM-SDK bevorzugen (fvm use, siehe docs/RELEASE.md):
    # der Hook formatiert dann mit derselben dart-Fassung wie Pruefkette und
    # CI. Ohne .fvm/ gilt wie bisher das dart aus dem PATH.
    $dart = Join-Path $PSScriptRoot '..\..\Automation_App_Frontend\.fvm\flutter_sdk\bin\dart.bat'
    if (-not (Test-Path -LiteralPath $dart)) { $dart = 'dart' }

    & $dart format $pfad | Out-Null
}
catch {
    # bewusst leer, siehe Kopf
}

exit 0
