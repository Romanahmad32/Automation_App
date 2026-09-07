---
name: issue-loesen
description: >-
  Ein GitHub-Issue dieses Repositories von der Bestandsaufnahme bis zur geprüften lokalen Lösung
  bearbeiten. Verwenden bei „Issue lösen/bearbeiten/aussuchen“, einer Issue-Nummer als Auftrag
  oder „GitHub-Issue umsetzen“.
---

# GitHub-Issue lösen

Lies `.claude/skills/issue-loesen/SKILL.md` vollständig. Sie enthält die gemeinsame fachliche
Checkliste. Wende sie mit folgenden Codex-Anpassungen an:

1. Nutze für GitHub den verfügbaren authentifizierten Connector oder `gh`; Websuche ist nur ein
   Ersatz für öffentlich lesbare Informationen.
2. „Master-Agent“ bedeutet der koordinierende Codex-Agent. Erstelle keine separate Codex-Aufgabe
   für eine Teilaufgabe.
3. Delegiere nur, wenn der Nutzer oder höherrangige Laufzeitanweisungen Subagenten erlauben. Wenn
   nicht, bearbeite Erhebung, Umsetzung und Review nacheinander selbst.
4. Verwende keine fest verdrahteten Claude-Modelle wie Opus oder Sonnet. Bei erlaubter Delegation
   das aktuelle Modell erben lassen, außer der Nutzer verlangt ausdrücklich ein anderes.
5. Bei erlaubter Delegation zuerst den Skill `subagent-auftrag` anwenden und Dateimengen disjunkt
   halten. Der koordinierende Agent bleibt für Integration und abschließende Prüfung zuständig.
6. Bei sichtbaren UI-Änderungen eine konkrete Vorschau zur Freigabe vorbereiten, wenn die
   Gestaltungsentscheidung den Nutzerwillen materiell betrifft; bereits eindeutig geforderte oder
   rein mechanische Änderungen nicht künstlich anhalten.
7. Nicht committen, pushen oder einen Pull Request erstellen, sofern der Nutzer das nicht verlangt.
   Branches nur auf Auftrag und mit den Präfixen aus `docs/RELEASE.md` anlegen.
8. Prüfprozesse im Vordergrund und mit begrenzter Wartezeit ausführen. Keine Hintergrundprozesse
   mit `Wait-Process` überwachen.

Nutzer- und Systemanweisungen gehen in jedem Konflikt vor dieser Checkliste.
