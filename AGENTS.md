# AGENTS.md — Codex-Einstieg

Diese Datei gilt für das gesamte Repository. Sie bleibt bewusst kurz: Die vorhandenen
`CLAUDE.md`-Dateien sind das gemeinsame, ausführliche Projekthandbuch für Menschen, Claude Code
und Codex. Vor jeder Codeänderung die Wurzel-`CLAUDE.md` vollständig lesen und ihre Verweise
befolgen. Bei fachlichem Verhalten ist `REQUIREMENTS.md` bindend; nichts ergänzen oder erraten,
was dort nicht gefordert ist.

## Teilbäume

- Unter `Automation_App_Frontend/` gilt zusätzlich die dortige `AGENTS.md`; sie lädt die
  ausführlichen Flutter-Regeln aus der benachbarten `CLAUDE.md`.
- Unter `AutomationService/` gilt zusätzlich die dortige `AGENTS.md`; sie lädt die ausführlichen
  Backend-Regeln aus der benachbarten `CLAUDE.md`.
- Vor der Arbeit an einem Feature zuerst dessen `FEATURE.md` lesen. Reicht die Änderung über ein
  Feature hinaus, außerdem `docs/DATENFLUESSE.md` lesen.

## Arbeitsweise

- Deutsch für Oberfläche, erzeugte Dokumente, Fachbegriffe und vorhandene deutsche Kommentare
  beibehalten.
- Vorhandene Änderungen gehören dem Nutzer: zuerst `git status --short` ansehen, nicht
  zurücksetzen und nicht beiläufig mitbearbeiten.
- Claude-spezifische Werkzeugnamen, Berechtigungsnotationen und Modellnamen in `.claude/` sind
  keine Codex-Anweisungen. Den fachlichen Ablauf mit den aktuell verfügbaren Codex-Werkzeugen
  umsetzen; höherrangige Nutzer- und Systemanweisungen gehen vor.
- Während der Arbeit gezielt testen. Vor Abschluss einer Codeänderung die in `CLAUDE.md`
  beschriebene passende Prüfkette ausführen; fehlende Toolchain ausdrücklich melden.
- Keine generierten Dateien von Hand ändern. Schreibende Formatierer nur auf Dateien oder
  Teilbäume anwenden, die zum Auftrag gehören.
- Keine Branches wechseln oder anlegen, nicht committen, pushen oder Pull Requests erstellen,
  sofern der Nutzer das nicht verlangt. Bei einem verlangten Branch gelten die Präfixe aus
  `docs/RELEASE.md`.

## Projekt-Skills

Wiederkehrende Abläufe liegen unter `.agents/skills/` und werden von Codex anhand ihrer
Beschreibung geladen:

- `neuer-endpunkt`: HTTP-Vertrag über Backend und Frontend ändern.
- `pruefen`: zentrale Prüfkette wie in CI ausführen und auswerten.
- `generieren`: Flutter-Codegenerierung ausführen und prüfen.
- `issue-loesen`: ein GitHub-Issue strukturiert bearbeiten.
- `subagent-auftrag`: nur bei ausdrücklich gewünschter oder erlaubter Delegation einen sicheren,
  abgegrenzten Subagentenauftrag formulieren.

Die gemeinsame Quelle und die Abgrenzung zur Claude-Konfiguration stehen in
`.agents/README.md`.
