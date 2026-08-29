# Haelt einen neuen Zweig an, dessen Name die Konvention verletzt.
#
# Aufgerufen als PreToolUse-Hook vor Bash/PowerShell; die Nutzlast kommt als
# JSON auf stdin. Der Hook laesst alles durch ausser dem Anlegen eines Zweigs
# (`git checkout -b`, `git switch -c`, `git branch <name>`).
#
# Warum hier und nicht erst in der CI: Umbenennen kostet vor dem ersten Commit
# nichts. Faellt der Name erst im Pull Request auf, haengen Commits, ein Push
# und womoeglich schon eine Rueckmeldung daran — dann bleibt er meistens
# stehen, und die Konvention ist eine Empfehlung geworden.
#
# Eine Stoerung des Hooks selbst (unlesbare Nutzlast, unerwartete Befehlsform)
# laesst durch und schweigt: Der CI-Schritt "Zweigname" prueft ohnehin nach.

$ErrorActionPreference = 'SilentlyContinue'

# Dieselbe Liste wie im CI-Schritt. Wer sie hier aendert, aendert sie dort mit.
$erlaubt = '^(feature|bugfix)/'

try {
    $roh = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($roh)) { exit 0 }

    $befehl = ($roh | ConvertFrom-Json).tool_input.command
    if (-not $befehl) { exit 0 }

    # Nur die Formen, mit denen hier tatsaechlich ein Zweig entsteht. `git
    # branch` ohne Namen listet nur auf, `git branch -d` loescht — deshalb
    # zaehlt dort nur ein Argument, das nicht mit einem Strich beginnt.
    $muster = @(
        'git\s+checkout\s+-[bB]\s+(\S+)',
        'git\s+switch\s+-[cC]\s+(\S+)',
        'git\s+branch\s+(?!-)(\S+)'
    )

    $name = $null
    foreach ($m in $muster) {
        $treffer = [regex]::Match($befehl, $m)
        if ($treffer.Success) { $name = $treffer.Groups[1].Value; break }
    }
    if (-not $name) { exit 0 }

    # Anfuehrungszeichen abstreifen, damit `git checkout -b "feature/x"` nicht
    # an seinen eigenen Zeichen scheitert.
    $name = $name.Trim("'", '"')

    if ($name -notmatch $erlaubt) {
        $vorschlag = ($name -replace '^[^/]*/', '')
        # Nicht Write-Error: Das $ErrorActionPreference oben (das jede eigene
        # Stoerung schlucken soll) verschluckt auch die Begruendung — der
        # Aufruf braeche dann wortlos ab. Der Fehlerstrom wird deshalb direkt
        # beschrieben.
        [Console]::Error.WriteLine(@"
Der Zweigname "$name" traegt kein zulaessiges Praefix. Der Zweig wurde nicht
angelegt.

  feature/  eine neue oder geaenderte Faehigkeit
  bugfix/   ein behobener Fehler

  git checkout -b feature/$vorschlag
  git checkout -b bugfix/$vorschlag

Das Praefix sagt schon in der Zweigliste und im Pull Request, worum es geht,
ohne dass jemand den Diff aufmacht. Der CI-Schritt "Zweigname" prueft dasselbe
am Pull Request; hier ist Umbenennen noch kostenlos.

(dependabot/… ist ausgenommen — diese Zweige legt niemand von Hand an.
Einzelheiten in docs/RELEASE.md.)
"@)
        exit 2
    }
}
catch {
    # bewusst leer, siehe Kopf
}

exit 0
