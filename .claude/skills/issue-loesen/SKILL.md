---
name: issue-loesen
description: >-
  Checkliste fuer den Master-Agenten, ein GitHub-Issue von der Auswahl bis zum Pull Request zu
  loesen: Zweig nach Label, eine gebuendelte Erhebung, bei sichtbarer Oberflaeche eine
  Design-Freigabe, Bausteine vor Umstellung, parallele Subagenten, Doku und Waechter, dann die
  Pruefkette. Verwenden bei "Issue loesen/bearbeiten/aussuchen", "/issue-loesen <nr>" oder
  "GitHub-Issue umsetzen".
---

# Ein GitHub-Issue lösen: der Ablauf

Checkliste für den Master-Agenten. Die Umsetzungsschritte (5–7) delegieren an Subagenten — deren
Auftrag baut auf dem Skill `.claude/skills/subagent-auftrag/SKILL.md` auf, damit Modellwahl,
Umgebungsfallstricke und Regeln nicht jedes Mal neu formuliert werden.

1. **Issue lesen** (`gh issue view <nr>`). Zahlen im Issue misstrauen — der Bestand wächst
   zwischen Anlage und Bearbeitung, heute per `grep` nachzählen statt der im Issue genannten
   Zahl zu glauben. Betrifft die Änderung fachliches Verhalten, zusätzlich `REQUIREMENTS.md`
   lesen. *Warum:* ein Issue vom Anlagezeitpunkt beschreibt einen Stand, der beim Bearbeiten oft
   nicht mehr stimmt.

2. **Zweig ab `origin/master`** anlegen, Präfix nach Label: `bug` → `bugfix/`, `enhancement` →
   `feature/` (`docs/RELEASE.md`), Name trägt die Issue-Nummer. *Warum:* Zweigliste und
   PR-Übersicht zeigen so auf einen Blick, ob es Reparatur oder Zuwachs ist — diese Auskunft
   trägt der Zweigname, nicht der Commit-Text.

3. **EINE Erhebung** (Opus): Bestand der Aufrufstellen, vorhandene Bausteine, betroffene
   Regeln/Tests, Testkonventionen — bei sichtbarer Oberfläche zugleich die Designsprache (Theme,
   Radius, Flächen, Muster) miterheben. Nicht zwei Agenten nacheinander. *Warum:* eine zweite
   Erhebung liest denselben Code wie die erste und verdoppelt die Kosten, ohne mehr zu liefern.

4. **Bei sichtbarer Oberfläche**: Verhalten und Gestalt MIT dem Nutzer festlegen
   (AskUserQuestion mit ASCII-Vorschauen), dann eine Vorschau über den Skill `design` (Opus)
   bauen lassen und die Freigabe abwarten. Mechanik und Tests dürfen parallel entstehen,
   Aufrufstellen erst nach Freigabe umstellen. *Warum:* der Nutzer will die Optik nicht nach
   Gutdünken des Agenten, sondern abgestimmt — Bau vor Freigabe hat schon Nacharbeit erzwungen.

5. **Baustein bauen** (Opus) mit exakt festgelegter öffentlicher API, damit Umstellungsagenten
   dagegen arbeiten können; der Bauagent liefert dazu eine Liste „was könnte schiefgehen" mit
   Tests. *Warum:* eine Schnittstelle, die sich noch ändert, bricht jede parallele Umstellung,
   die schon dagegen baut.

6. **Umstellung parallel** (Sonnet), disjunkte Dateimengen je Agent, Auftrag über den Skill
   `subagent-auftrag`. *Warum:* das ist mechanische Arbeit, für die Sonnet reicht, und
   disjunkte Dateien verhindern, dass sich Agenten gegenseitig überschreiben.

7. **Doku und Wächter** (Sonnet): `docs/STAND.md`, die zutreffende Regeltabelle (Wurzel-
   `CLAUDE.md` oder die des betroffenen Teilbaums), ein Architekturtest, wenn sich die Regel
   prüfen lässt (mit Negativtest belegt). *Warum:* eine Regel ohne Test verfällt beim nächsten
   Refactor unbemerkt — genau das, wogegen die Prüfkette dieses Repos steht.

8. **Review-Agent** (Sonnet, nur lesend) PARALLEL zu `scripts/check.ps1 -Regeln` laufen
   lassen; Befunde beheben lassen. Erst danach die volle Kette `scripts/check.ps1` GENAU
   EINMAL — per PowerShell-Tool mit absolutem Pfad, im Hintergrund mit Timeout 600000 (dauert
   rund zehn Minuten). *Warum:* die volle Kette zweimal laufen zu lassen, verdoppelt zehn
   Minuten Wartezeit ohne neuen Erkenntnisgewinn, wenn die Regeln schon grün sind.

9. **Master prüft selbst nur Billiges**: `grep` auf Vollständigkeit, `git status`,
   Stichproben-`git diff`. *Warum:* alles Teurere hat Schritt 8 schon erledigt — der Master
   wiederholt es nicht, er stichprobt nur.

10. **Commit** auf dem Zweig mit Warum-Text und `Co-Authored-By` — ohne Nachfrage, sobald die
    Kette grün ist. **Push und Pull Request** (`gh pr create`, „Schließt #<nr>") erst auf
    ausdrückliche Anweisung des Nutzers. *Warum:* ein lokaler Commit sichert die Arbeit, ein Push
    macht sie nach außen sichtbar — über diesen Zeitpunkt entscheidet der Nutzer.

## Woran es zuletzt gescheitert ist

- **Bau vor Designfreigabe**: der Baustein wurde gebaut, bevor Position und Gestalt mit dem
  Nutzer abgestimmt waren — der Bauagent musste mitten im Bau umgesteuert werden, und ein
  parallel gestarteter Vorschau-Agent las den halbfertigen Code und meldete Abweichungen, die es
  am Ende nicht gab.
- **Volle Kette zweimal**: `scripts/check.ps1` lief vor und nach den Korrekturen komplett
  durch — zehn Minuten Wartezeit doppelt bezahlt, obwohl `-Regeln` plus Review-Agent gereicht
  hätten.
- **Hängender Hintergrund-Test**: ein Subagent startete einen Test im Hintergrund und wartete
  mit `Wait-Process` darauf — die Sitzung hing fest (04.09.2026, Issue #56).
