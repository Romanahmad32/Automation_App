# Sucht Geheimnisse in dem, was gerade committet werden soll.
#
# Aufgerufen als PreToolUse-Hook vor Bash/PowerShell; die Nutzlast kommt als
# JSON auf stdin. Der Hook laesst alles durch ausser einem `git commit`.
#
# Warum zusaetzlich zur CI: Die CI faengt den Fund erst, wenn der Commit
# gepusht ist — dann steht der Zugang bereits in der Historie und gilt als
# verbrannt, auch wenn der naechste Commit ihn entfernt. Hier faellt er
# davor auf, solange Zuruecknehmen noch nichts kostet.
#
# Zwei Ausgaenge, und nur diese: Ein *Fund* blockiert den Aufruf (Exit 2,
# Begruendung auf stderr). Alles andere — kein gitleaks da, Docker aus,
# unlesbare Nutzlast, Zeitueberschreitung — laesst durch und schweigt. Ein
# Waechter, der bei eigener Stoerung die Arbeit anhaelt, wird abgeschaltet,
# und dann bewacht er gar nichts mehr. Die CI prueft ohnehin nach.

$ErrorActionPreference = 'SilentlyContinue'

try {
    $roh = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($roh)) { exit 0 }

    $eingabe = $roh | ConvertFrom-Json
    $befehl = $eingabe.tool_input.command
    if (-not $befehl) { exit 0 }

    # Nur echte Commits. `git commit` in einer Zeichenkette (etwa in einer
    # Commit-Nachricht, die von einem Commit erzaehlt) faengt das mit, kostet
    # aber nur einen ueberfluessigen Scan — der umgekehrte Fehler waere teurer.
    if ($befehl -notmatch '\bgit\s+commit\b') { exit 0 }

    $wurzel = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

    # gitleaks meldet seine Funde auf dem Fehlerstrom. Mit dem
    # SilentlyContinue oben faellt jede dieser Zeilen weg — der Hook
    # blockierte dann mit einer Begruendung ohne Fundstelle, und wer sie
    # sehen will, muesste gitleaks von Hand nachfahren. Deshalb fuer die
    # Dauer des Aufrufs zurueckgeschaltet.
    $vorher = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # Native Installation bevorzugt, sonst dasselbe Abbild wie in der CI —
        # dieselbe Fassung, damit hier und dort dieselben Regeln gelten.
        if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
            $ausgabe = & gitleaks git $wurzel --staged --no-banner --redact -v 2>&1 |
                ForEach-Object { [string]$_ }
        }
        elseif (Get-Command docker -ErrorAction SilentlyContinue) {
            $ausgabe = & docker run --rm -v "${wurzel}:/repo" `
                zricethezav/gitleaks:v8.30.1 git /repo --staged --no-banner --redact -v 2>&1 |
                ForEach-Object { [string]$_ }
        }
        else {
            exit 0
        }
    }
    finally {
        $ErrorActionPreference = $vorher
    }

    # Exit 1 heisst bei gitleaks "Fund", nicht "Fehler" (Fehler ist Exit 2).
    # Nur der Fund darf blockieren; alles andere ist eine Stoerung des
    # Werkzeugs und geht den Commit nichts an.
    if ($LASTEXITCODE -eq 1) {
        # Nicht Write-Error: Das $ErrorActionPreference oben (das jede eigene
        # Stoerung schlucken soll) verschluckt auch die Begruendung — der
        # Aufruf braeche dann wortlos ab. Der Fehlerstrom wird deshalb direkt
        # beschrieben.
        [Console]::Error.WriteLine(@"
gitleaks hat in den vorgemerkten Aenderungen ein Geheimnis gefunden. Der Commit
wurde nicht ausgefuehrt.

$($ausgabe -join [Environment]::NewLine)

Den Fund aus der Aenderung nehmen, nicht den Hook umgehen: Ist er erst
committet, steht er in der Historie und gilt als verbrannt — dann hilft nur
noch, den Zugang zu wechseln. Zugangsdaten gehoeren zur Laufzeit nach
%APPDATA%, nicht in eine versionierte Datei (docs/POSTFACH_SETUP.md).

Falscher Alarm? Dann gehoert eine Regel-Ausnahme in eine .gitleaks.toml im
Wurzelverzeichnis — namentlich und mit Begruendung, wie jede andere Ausnahme
in diesem Repository.
"@)
        exit 2
    }
}
catch {
    # bewusst leer, siehe Kopf
}

exit 0
