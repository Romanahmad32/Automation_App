# Sperrt gefaehrliche Bedienschritte, die ein KI-Agent per Marionette MCP
# in der laufenden App ausloesen koennte.
#
# Aufgerufen als PreToolUse-Hook mit dem Matcher `mcp__marionette__.*`, also nur
# bei Marionette-Werkzeugen -- bei jedem anderen Aufruf startet er gar nicht und
# kostet nichts. Die Nutzlast (tool_name, tool_input) kommt als JSON auf stdin;
# die Antwort geht als JSON auf stdout, Exit immer 0.
#
# Hintergrund: Bei einem frueheren Test hat ein Fehlklick die echte
# Zentralruf-Automation ausgeloest (Browser, echte Anfrage an die Versicherer).
# Das darf sich nicht wiederholen, auch nicht bei einem Agenten, der sich irrt.
#
#   deny  Zentralruf-, Senden-, Versenden-, Drucken-Knoepfe (nach aussen wirkend)
#   ask   Outlook-Entwurf, Postfach verbinden/testen/anmelden, Sicherung
#         einspielen, Import; Tippen ueber coordinates/type (umgeht jede
#         Pruefung); press_key mit Enter/Leertaste; call_custom_extension
#   allow alles andere
#
# Kann die Eingabe nicht gelesen werden, wird ASK ausgegeben -- ein Wachter, der
# bei eigener Stoerung durchwinkt, schuetzt nichts.
#
# Windows PowerShell 5.1 liest eine UTF-8-Datei ohne BOM als ANSI. Diese Datei
# bleibt deshalb reines ASCII; Umlaute stehen in den Mustern als ä usw.
# Stdin wird als UTF-8 gelesen, damit "ausfuellen" mit Umlaut richtig ankommt.

$ErrorActionPreference = 'Stop'

function Antworte([string]$entscheidung, [string]$grund) {
    $antwort = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $entscheidung
            permissionDecisionReason = $grund
        }
    }
    # Ausgabe als ASCII-sicheres JSON: ConvertTo-Json laesst Umlaute stehen, die
    # Konsole kann sie je nach Codepage zerbrechen. Darum nicht-ASCII maskieren.
    $json = $antwort | ConvertTo-Json -Compress -Depth 5
    $json = [regex]::Replace($json, '[^\u0000-\u007F]', {
            param($m) '\u{0:x4}' -f [int][char]$m.Value
        })
    [Console]::Out.WriteLine($json)
    exit 0
}

# Zentralruf, Senden/Versenden, Drucken. "verfassen" ist ausgenommen: Der Knopf
# "E-Mail verfassen und senden" oeffnet nur den Dialog; gesendet wird erst im
# Bestaetigungsdialog ("Senden"), und der ist gesperrt.
$sperrMuster = @(
    @{ Muster = 'zentralruf'; Grund = 'startet die echte Zentralruf-Automation (Browser, Anfrage an die Versicherer)'; Ausnahme = $null }
    @{ Muster = '(?<!ab)senden|sendet|versend|versandt'; Grund = 'sendet eine echte E-Mail'; Ausnahme = 'verfassen' }
    @{ Muster = 'druck|print'; Grund = 'druckt auf einem echten Drucker'; Ausnahme = $null }
)

$frageMuster = @(
    @{ Muster = 'entwurf|outlook'; Grund = 'oeffnet einen Entwurf in Outlook' }
    @{ Muster = 'verbind|verbunden|testen|anmelden|abmelden'; Grund = 'verbindet das Postfach oder testet die Verbindung' }
    @{ Muster = 'wiederherst|einspiel|import'; Grund = 'spielt eine Sicherung bzw. Daten ein und ueberschreibt den Bestand' }
)

try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    $roh = [Console]::In.ReadToEnd()
    $eingabe = $roh | ConvertFrom-Json
    if ($null -eq $eingabe -or -not $eingabe.tool_name) { throw 'kein tool_name' }

    $werkzeug = [string]$eingabe.tool_name
    $werkzeug = $werkzeug -replace '^mcp__marionette__', ''
    $felder = $eingabe.tool_input

    # Texte, gegen die geprueft wird: die Zielselektoren. Bei enter_text ist
    # `text` der einzutippende Inhalt, kein Selektor, und `key` bei press_key
    # ist eine Taste -- beide zaehlen hier nicht.
    $ziele = @()
    if ($felder -and $werkzeug -notin @('enter_text', 'press_key', 'call_custom_extension')) {
        foreach ($name in 'key', 'identifier', 'text') {
            $wert = $felder.$name
            if ($null -ne $wert) { $ziele += [string]$wert }
        }
        foreach ($k in @($felder.ancestor_keys)) {
            if ($null -ne $k) { $ziele += [string]$k }
        }
    }

    foreach ($ziel in $ziele) {
        foreach ($regel in $sperrMuster) {
            if ($ziel -match "(?i)$($regel.Muster)") {
                if ($regel.Ausnahme -and $ziel -match "(?i)$($regel.Ausnahme)") { continue }
                Antworte 'deny' "Marionette-Sperre: '$ziel' $($regel.Grund). Dieser Schritt ist dem Agenten verboten, auch wenn es ein Test ist; der Mensch bedient ihn selbst."
            }
        }
    }

    foreach ($ziel in $ziele) {
        foreach ($regel in $frageMuster) {
            if ($ziel -match "(?i)$($regel.Muster)") {
                Antworte 'ask' "Marionette-Sperre: '$ziel' $($regel.Grund). Bitte bewusst freigeben."
            }
        }
    }

    $tippen = @('tap', 'double_tap', 'long_press', 'secondary_tap')
    if ($werkzeug -in $tippen -and $felder) {
        if ($null -ne $felder.coordinates) {
            Antworte 'ask' 'Marionette-Sperre: Tippen ueber coordinates umgeht die Pruefung der Knopfbeschriftung. Bitte bewusst freigeben.'
        }
        if ($null -ne $felder.type -and $null -eq $felder.key -and $null -eq $felder.identifier -and $null -eq $felder.text) {
            Antworte 'ask' 'Marionette-Sperre: Tippen ueber type trifft irgendeinen Knopf dieses Typs und umgeht die Pruefung. Bitte bewusst freigeben.'
        }
    }

    if ($werkzeug -eq 'press_key') {
        $taste = [string]$felder.key
        if ($taste -match '(?i)^(enter|return|space|leertaste|numpadenter)$') {
            Antworte 'ask' "Marionette-Sperre: Taste '$taste' loest den fokussierten Knopf aus, ohne dass seine Beschriftung geprueft werden kann. Bitte bewusst freigeben."
        }
    }

    if ($werkzeug -eq 'call_custom_extension') {
        Antworte 'ask' 'Marionette-Sperre: call_custom_extension ruft App-eigenen Code auf, dessen Wirkung der Hook nicht kennt. Bitte bewusst freigeben.'
    }

    Antworte 'allow' 'Marionette-Sperre: kein gefaehrlicher Bedienschritt erkannt.'
}
catch {
    Antworte 'ask' 'Marionette-Sperre: Die Hook-Eingabe war nicht lesbar. Aus Vorsicht nachfragen statt durchwinken.'
}
