# AGENTS.md — Backend

Gilt für `AutomationService/` zusätzlich zur Wurzel-`AGENTS.md`.

Vor jeder Änderung in diesem Teilbaum `AutomationService/CLAUDE.md` vollständig lesen und als
verbindliches Backend-Handbuch anwenden. Für HTTP-Vertragsänderungen zusätzlich den Projekt-Skill
`neuer-endpunkt` verwenden; `docs/openapi.json` wird durch den Vertragstest erzeugt und nicht von
Hand gepflegt.

Backend-Befehle aus `AutomationService/AutomationService/` ausführen. Zunächst den kleinsten
aussagekräftigen Test starten; den vollständigen Prüfumfang bestimmt die Wurzel-`AGENTS.md`.
