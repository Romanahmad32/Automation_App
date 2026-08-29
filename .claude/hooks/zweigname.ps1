# Haelt einen neuen Zweig an, dessen Name die Konvention verletzt.
#
# Aufgerufen als PreToolUse-Hook vor Bash/PowerShell; die Nutzlast kommt als
# JSON auf stdin. Der Hook laesst alles durch ausser dem Anlegen und
# Umbenennen eines Zweigs.
#
# Warum hier und nicht erst in der CI: Umbenennen kostet vor dem ersten Commit
# nichts. Faellt der Name erst im Pull Request auf, haengen Commits, ein Push
# und womoeglich schon eine Rueckmeldung daran — dann bleibt er meistens
# stehen, und die Konvention ist eine Empfehlung geworden.
#
# Warum ein Agenten-Hook und kein Git-Hook wie der Geheimnis-Waechter:
# `.githooks/` kennt kein Ereignis fuers Anlegen eines Zweigs — `post-checkout`
# laeuft erst danach und kann nichts mehr verhindern. Hier ist die frueheste
# Stelle, die es gibt. Der Preis ist ein PowerShell-Start je Werkzeugaufruf
# (gemessen rund 400 ms), denn der Matcher trifft nur das Werkzeug, nicht den
# Befehl. Ein Shell-Skript waere rund viermal billiger, faellt aber aus: `bash`
# auf dem Windows-PATH ist der WSL-Starter (C:\WINDOWS\system32\bash.exe),
# nicht das Git-Bash daneben.
#
# Der Hook sieht nur Zeichenketten und kann einen Befehl nicht von Prosa ueber
# einen Befehl unterscheiden — wer eine Beispielzeile in eine Datei schreibt,
# loest ihn mit aus. Das ist der Grund, die Muster unten eng zu fassen: Was vor
# jedem Werkzeugaufruf laeuft, muss vor allem selten irren.
#
# Eine Stoerung des Hooks selbst (unlesbare Nutzlast, unerwartete Befehlsform)
# laesst durch und schweigt: Der CI-Schritt "Zweigname" prueft ohnehin nach.

$ErrorActionPreference = 'SilentlyContinue'

# Dieselbe Liste wie im CI-Schritt, dependabot/ eingeschlossen. Ohne den
# dritten Zweig hielte der Hook an, was `gh pr checkout` bei einem
# Abhaengigkeits-PR absetzt — ausgerechnet die Zweigform, fuer die die CI
# ausdruecklich eine Ausnahme hat.
$erlaubt = '^(feature|bugfix|dependabot)/'

try {
    $roh = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($roh)) { exit 0 }

    $befehl = ($roh | ConvertFrom-Json).tool_input.command
    if (-not $befehl) { exit 0 }

    # Woraus ein Zweigname besteht. Bewusst nicht `\S+`: Das fing in
    # `git branch | grep master` die Pipe und hielt den Aufruf mit der Meldung
    # an, "|" trage kein zulaessiges Praefix. Zweige auflisten und durchsuchen
    # ist ein Alltagsbefehl.
    #
    # Der Bindestrich gehoert in den Vorrat — `feature/zwei-namen` ist ein
    # gueltiger Name —, darf aber nicht am Anfang stehen. Sonst liest sich
    # jeder Schalter als Zweigname und `git branch -a` wird derselbe
    # Fehltreffer eine Ebene tiefer.
    $zeichen = '[A-Za-z0-9._/][A-Za-z0-9._/-]*'
    # Aussen stehende Anfuehrungszeichen duerfen sein.
    $q = '["'']?'

    # Nur die Formen, mit denen hier tatsaechlich ein Zweigname entsteht.
    # Auflisten und loeschen fallen von allein heraus: Ihre Argumente fangen
    # mit einem Strich an, ein Zweigname nie.
    $muster = @(
        "git\s+checkout\s+-[bB]\s+$q($zeichen)$q",
        "git\s+switch\s+(?:-[cC]|--create|--force-create)\s+$q($zeichen)$q",
        # Umbenennen, ein- wie zweiargumentig: der letzte Name ist der neue.
        "git\s+branch\s+(?:-[mM]|--move)\s+(?:$q$zeichen$q\s+)?$q($zeichen)$q",
        "git\s+branch\s+$q($zeichen)$q"
    )

    $name = $null
    foreach ($m in $muster) {
        $treffer = [regex]::Match($befehl, $m)
        if ($treffer.Success) { $name = $treffer.Groups[1].Value; break }
    }
    if (-not $name) { exit 0 }

    # -cnotmatch, nicht -notmatch: PowerShell vergleicht sonst ohne Ruecksicht
    # auf Gross-/Kleinschreibung, das `case` im CI-Schritt aber mit. Ein Name
    # mit grossem Anfangsbuchstaben entstuende hier klaglos und wuerde erst im
    # Pull Request rot — genau die Reihenfolge, gegen die der Hook steht.
    if ($name -cnotmatch $erlaubt) {
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

Gross- und Kleinschreibung zaehlt mit; das Praefix steht klein.

Das Praefix sagt schon in der Zweigliste und im Pull Request, worum es geht,
ohne dass jemand den Diff aufmacht. Der CI-Schritt "Zweigname" prueft dasselbe
am Pull Request; hier ist Umbenennen noch kostenlos.

(Von Dependabot angelegte Zweige sind ausgenommen — die legt niemand von Hand
an. Einzelheiten in docs/RELEASE.md.)
"@)
        exit 2
    }
}
catch {
    # bewusst leer, siehe Kopf
}

exit 0
