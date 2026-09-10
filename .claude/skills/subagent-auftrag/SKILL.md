---
name: subagent-auftrag
description: >-
  Wie ein koordinierender Agent (Master) einen Auftrag an einen Subagenten zuschneidet: welche
  Agentendefinition bzw. welches Modell, wie die Dateimengen getrennt werden, was in den Auftrag
  gehoert und was der Master danach selbst verifiziert. Verwenden, sobald ein Agent einen Auftrag
  an einen Subagenten formuliert -- Subagent beauftragen, das Agent-Tool aufrufen, Umsetzung
  delegieren.
---

# Auftrag an einen Subagenten: der Zuschnitt

Die verbindlichen Regeln und die Umgebungsfallstricke stehen **nicht mehr hier**, sondern in der
Agentendefinition [`.claude/agents/umsetzer.md`](../../agents/umsetzer.md): Dateilängen, private
Typen, gepinntes SDK, kein Hintergrundprozess, Berichtsformat. Wer den `umsetzer` beauftragt,
bekommt sie automatisch — sie mussten vorher in jeden Auftrag hineinkopiert werden, und ein
vergessener Punkt (Zweig gewechselt, Hintergrundtest gestartet) hat schon Sitzungen gekostet.

Dieser Skill sagt nur noch, was der Master selbst entscheiden muss.

## Wen beauftragen

- **`umsetzer`** (`subagent_type: "umsetzer"`, läuft auf Sonnet) für mechanische Arbeit nach
  vorgegebenem Muster: viele gleichartige Aufrufstellen umstellen, Doku nachziehen, Befunde
  beheben. Der Regelteil ist damit erledigt; der Auftrag beschreibt nur noch die Sache.
- **Opus** für Recherche und für Bausteine mit Architekturanteil (neue Schnittstelle, neuer
  senkrechter Schnitt) — hier zahlt sich das teurere Modell aus, weil ein falscher Zuschnitt jede
  Umstellung danach mitreißt. Dabei `model` **immer explizit setzen**: ohne Angabe läuft der Agent
  auf dem teuren Hauptmodell, das Kontingent leidet, und beim Start fällt es nicht auf.
- Braucht ein Opus-Agent dieselben Projektregeln, verweist der Auftrag auf
  `.claude/agents/umsetzer.md` statt sie neu zu tippen.

## Wie zuschneiden

- **Parallele Agenten bekommen disjunkte Dateimengen.** Zwei Agenten in derselben Datei
  überschreiben sich gegenseitig oder bauen gegen den Zwischenstand des anderen. Wo sich eine
  gemeinsam genutzte Datei nicht vermeiden lässt (Wurzel-`CLAUDE.md`), gehört in den Auftrag:
  nur kleine, gezielte Ersetzungen, nie die Datei neu schreiben.
- **Der Auftrag nennt die fremden Bereiche mit.** „Agent B arbeitet an `scripts/` — nicht
  anfassen" verhindert mehr als jede Ermahnung, sorgfältig zu sein.
- **Erhebungsagenten laufen nicht parallel zu Bauagenten an denselben Dateien** — sonst sehen sie
  einen Stand, der sich noch ändert, und ihr Befund ist beim Bericht schon veraltet.

## Was in den Auftrag gehört

Vier Angaben, mehr nicht: das gewünschte Ergebnis; die Dateien bzw. Ordner, die dem Agenten
allein gehören; die fremden Bereiche, die er nicht anfassen darf; welche Vorlage er vorher lesen
soll (Issue, `FEATURE.md`, Erhebungsbericht).

## Was der Master danach verifiziert

Der Bericht eines Subagenten ist eine Behauptung, keine Prüfung. Der Master sieht selbst nach —
und zwar nur Billiges, weil alles Teurere die zentrale Prüfkette ohnehin macht:

- `git status --short` und ein Stichproben-`git diff`: Wurde angefasst, was angefasst werden
  sollte — und nichts darüber hinaus?
- `grep` auf Vollständigkeit: Ist der gemeldete Umfang wirklich umgestellt?
- das wörtlich zitierte Prüfergebnis im Bericht. Fehlt es oder steht dort eine Zusammenfassung
  statt der Ausgabe, gilt der Teil als ungeprüft.

Erst wenn alle Agenten zurück sind, läuft `scripts/check.ps1` — genau einmal.
