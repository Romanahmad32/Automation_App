# Codex-Projektkonfiguration (`.agents/`)

Codex entdeckt die Wurzel- und Teilbaumdateien `AGENTS.md` automatisch. Wiederverwendbare
Projektabläufe entdeckt es anhand der Metadaten in `.agents/skills/*/SKILL.md` und lädt den Inhalt
erst, wenn eine Aufgabe dazu passt.

Die ausführliche Projektdokumentation bleibt bewusst an einer Stelle:

- `CLAUDE.md` sowie die beiden Teilbaum-`CLAUDE.md` sind die gemeinsamen Handbücher.
- `.claude/skills/` und `.claude/commands/` enthalten die bereits gepflegten Ablaufdetails.
- `.agents/skills/` sind dünne Codex-Adapter. Sie verweisen auf die gemeinsame Quelle und
  übersetzen nur Claude-spezifische Werkzeug-, Modell- und Delegationsannahmen.

So laufen die Anleitungen nicht auseinander. Ändert sich ein allgemeiner Projektablauf, zuerst die
gemeinsame Quelle unter `.claude/` aktualisieren und danach prüfen, ob ein Codex-Adapter eine
abweichende Übersetzungsregel braucht. Rein Codex-spezifische Hinweise gehören in `AGENTS.md` oder
den betreffenden Adapter.

`.codex/agents/` enthält Projektagenten nach demselben Muster: `umsetzer.toml` verweist auf
`.claude/agents/umsetzer.md` und übersetzt nur Dateinamen und Werkzeugbegriffe. Ein Modell legt
er nicht fest — er erbt es vom Aufrufer.

Eine `.codex/config.toml` gibt es absichtlich nicht: Modell, Sandbox, Freigaben und persönliche
MCP-Verbindungen sind laufzeit- bzw. nutzerspezifisch. Das Repository legt nur seine fachlichen
Regeln, Befehle und Prüfabläufe fest.
