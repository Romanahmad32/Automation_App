---
name: subagent-auftrag
description: >-
  Sicheren, abgegrenzten Auftrag für einen Codex-Subagenten formulieren. Nur verwenden, wenn der
  Nutzer ausdrücklich Delegation verlangt oder höherrangige Laufzeitanweisungen sie erlauben und
  eine unabhängige Teilaufgabe wirklich parallel bearbeitet werden kann.
---

# Codex-Subagent beauftragen

Vor dem Start prüfen, dass Delegation zulässig ist, die Teilaufgabe unabhängig ist und kein anderer
Agent dieselben Dateien bearbeitet. Keine separate nutzerseitige Codex-Aufgabe anlegen; dafür die
verfügbaren internen Kollaborationswerkzeuge verwenden.

Der Auftrag muss enthalten:

- konkretes Ergebnis und exklusiven Datei-/Rechercheumfang,
- „Zweig nicht wechseln, nicht committen, nicht pushen“,
- Verweis auf Wurzel-`AGENTS.md`, betroffene Teilbaum-`AGENTS.md`, `REQUIREMENTS.md` bei
  Fachverhalten und die passenden `FEATURE.md`,
- Hinweis auf vorhandene Nutzeränderungen und das Verbot, sie zurückzusetzen,
- für Flutter das gepinnte SDK aus `.fvmrc`, Befehle im Vordergrund, keine
  `Wait-Process`- oder Hintergrund-Testschleifen,
- genau die gezielten Prüfungen, die der Agent selbst ausführen soll; zentrale Analyse,
  Architekturtests und volle Prüfkette bleiben beim koordinierenden Agenten,
- Berichtsformat: geänderte Dateien, nicht offensichtliche Entscheidungen, wörtliches
  Prüfergebnis, offene Punkte.

Das Modell nicht fest verdrahten. Standardmäßig das aktuelle Modell und Reasoning erben; nur eine
ausdrückliche Nutzervorgabe rechtfertigt eine Abweichung.
