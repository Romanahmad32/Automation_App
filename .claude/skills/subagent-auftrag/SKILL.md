---
name: subagent-auftrag
description: >-
  Boilerplate, das ein koordinierender Agent (Master) jedem Subagenten mitgibt, statt es jedes
  Mal neu zu tippen: Rollen- und Modellwahl, Umgebungsfallstricke, verbindliche Regeln und was
  der Subagent selbst noch pruefen darf, bevor er berichtet. Verwenden, sobald ein Agent einen
  Auftrag an einen Subagenten formuliert -- Subagent beauftragen, das Agent-Tool aufrufen,
  Umsetzung delegieren.
---

# Auftrag an einen Subagenten: der Baustein

Jeder Auftrag an einen frischen Subagenten braucht dieselben vier Dinge: welches Modell, welche
Umgebungsfallstricke, welche Regeln gelten und was er selbst noch prüfen darf, bevor er
berichtet. Ohne diesen Baustein tippt jeder Master-Agent das neu — unterschiedlich vollständig,
und ein vergessener Punkt (Zweig nicht wechseln, kein Hintergrundprozess) hat schon Sitzungen
gekostet. Die drei Textbausteine unten gehören wörtlich in den `prompt` des Agent-Tools.

## Rollen und Modelle

- **Opus** für Recherche und Bausteine mit Architekturanteil (neue Schnittstelle, neuer
  senkrechter Schnitt) — hier zahlt sich das teurere Modell aus, weil ein falscher Zuschnitt
  jede Umstellung danach mitreißt.
- **Sonnet** für die Umstellung vieler gleichartiger Stellen, Doku und Korrekturen — mechanische
  Arbeit nach vorgegebenem Muster, bei der ein teureres Modell nichts zusätzlich liefert.
- **`model` im Agent-Tool IMMER explizit setzen.** Ohne Angabe läuft der Agent auf dem teuren
  Hauptmodell statt auf Sonnet — das Kontingent leidet, ohne dass es beim Start auffällt.
- **Parallele Agenten bekommen disjunkte Dateimengen.** Zwei Agenten, die dieselbe Datei
  anfassen, überschreiben sich gegenseitig oder bauen gegen den Zwischenstand des anderen.
- **Erhebungsagenten laufen nicht parallel zu Bauagenten an denselben Dateien** — sonst sehen
  sie einen Stand, der sich noch ändert, und ihr Befund ist beim Bericht schon veraltet.

## Textbaustein „Umgebung" (wörtlich einfügen)

> Zweig nicht wechseln, nicht committen, nicht pushen. Das gepinnte Flutter-SDK verwenden (Version
> aus `FLUTTER_VERSION` bzw. `.fvmrc`; lokal liegt es unter
> `%USERPROFILE%\fvm\versions\<Version>\bin\flutter.bat` bzw. `dart.bat`) — nie `flutter` ohne
> Pfad, im PATH kann ein anderes SDK liegen. Alle Flutter-/PowerShell-Befehle über das
> PowerShell-Tool, im Vordergrund, Timeout
> 600000; KEIN `run_in_background`, keine `Wait-Process`-Schleifen, keine
> Hintergrund-Testprozesse (Agenten hängen sich daran auf). Widget-Test-Fehler
> „shaders/ink_sparkle.frag … Unsupported runtime stages format version" bedeutet Build-Cache aus
> falschem SDK, kein Codefehler → `flutter clean` + `pub get` mit dem gepinnten SDK. Dateien mit
> literalen Backslashes nur mit Edit- oder Write-Tool schreiben, nie per Bash-Heredoc (frisst
> `\\`). Versionierte Dateien nur per `git checkout -- <datei>` zurückstellen, nie per
> PowerShell-`Get-Content`/`Set-Content`-Roundtrip (zerstört UTF-8, setzt ein BOM). Neue Dateien
> mit CRLF anlegen, wie die Nachbardateien.

## Textbaustein „Regeln" (wörtlich einfügen)

> Zuerst `Automation_App_Frontend/CLAUDE.md` bzw. `AutomationService/CLAUDE.md` lesen, je
> nachdem welcher Teilbaum betroffen ist. Dazu die nicht verhandelbaren Regeln aus der
> Wurzel-`CLAUDE.md`, eine je Satz: Dateien kurz halten (250 Anweisungszeilen, 450 insgesamt);
> keine privaten Typen oder Top-Level-Funktionen im Frontend; Vorhandenes bevorzugen statt zu
> verdoppeln; ein roter Test wird grün, indem der Code repariert wird, nie die Testerwartung.
> Gehört die Änderung zu einem Feature mit Steckbrief, `FEATURE.md` mitpflegen.

## Textbaustein „Prüfen im Subagenten" (wörtlich einfügen)

> Nur `dart format` auf die eigenen Ordner und `flutter test <eigene Testordner>` laufen lassen.
> KEIN `flutter analyze`, KEINE Architekturtests, KEINE volle Suite — das läuft einmal zentral
> beim Master; bei vier parallelen Agenten mit je einem eigenen `analyze`-Lauf hat sich die
> Maschine sonst festgefahren (04.09.2026). Zum Abschluss ein `grep` als Beleg, dass der eigene
> Umfang vollständig umgestellt ist, in den Bericht aufnehmen.

## Berichtsformat

Jeder Subagent schließt mit:

- den geänderten Dateien (Pfad, keine Zusammenfassung ohne Pfad),
- nicht offensichtlichen Entscheidungen (warum diese Stelle so und nicht anders),
- dem Prüfergebnis **wörtlich** als letzte Zeile — nicht „Tests grün", sondern die tatsächliche
  Ausgabe, damit der Master einen Fehlschlag nicht hinter einer Zusammenfassung übersieht,
- offenen Punkten.

Hat ein Subagent ein Ergebnis nicht gesehen (Prozess abgebrochen, Timeout), schreibt er genau
das — „kein Ergebnis gesehen" statt einer Vermutung, was wohl passiert wäre.
