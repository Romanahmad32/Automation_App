---
name: neuer-endpunkt
description: >-
  Projektablauf für einen neuen oder geänderten HTTP-Endpunkt über ASP.NET-Backend,
  docs/openapi.json und Flutter-Frontend. Verwenden, sobald eine Aufgabe eine Route, ein DTO oder
  Feld, eine API-Datasource oder eine neue Tabelle berührt.
---

# HTTP-Endpunkt ändern

Lies `.claude/skills/neuer-endpunkt/SKILL.md` vollständig und wende das dort beschriebene Rezept
Backend → Vertrag → Frontend an. Diese Datei ist die gemeinsame fachliche Quelle.

Für Codex gelten dabei diese Übersetzungen:

- Lies zuerst die Wurzel-`AGENTS.md` sowie die betroffenen Teilbaum-`AGENTS.md` und die dort
  verlangten Handbücher.
- Verwende die aktuell verfügbaren Shell- und Dateiwerkzeuge; Claude-spezifische Werkzeugnamen
  aus benachbarten Dateien sind nur deren lokale Syntax.
- Bewahre vorhandene Nutzeränderungen. Der Vertragstest darf `docs/openapi.json` aktualisieren;
  prüfe anschließend den Diff und übernimm ihn nur, wenn er zur beabsichtigten API-Änderung passt.
- Führe während der Arbeit gezielte Tests aus und zum Schluss den Skill `pruefen`.
- Nutzer- und Systemanweisungen haben Vorrang vor dem Ablaufrezept.
