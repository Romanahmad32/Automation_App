---
name: pruefen
description: >-
  Zentrale Prüfkette dieses Repositories ausführen und auswerten. Verwenden bei „prüfen“,
  „Checks ausführen“, „wie CI testen“, vor dem Abschluss größerer Codeänderungen oder wenn nur
  Frontend-/Backend- bzw. Regelprüfungen verlangt sind.
---

# Repository prüfen

Lies `.claude/commands/pruefen.md` vollständig; sie ist die gemeinsame Beschreibung der
Prüfkette und ihrer Auswertung.

Führe aus der Repository-Wurzel den zum Auftrag passenden Befehl aus:

```powershell
./scripts/check.ps1
./scripts/check.ps1 -Regeln -NurFrontend
./scripts/check.ps1 -Regeln
./scripts/check.ps1 -NurFrontend
./scripts/check.ps1 -NurBackend
./scripts/check.ps1 -Beheben
```

`-Beheben` ist schreibend und gehört nur zum Auftrag, wenn Formatierung behoben werden soll. Zeige
bei Fehlern die maßgebliche Originalausgabe und trenne Codefehler von fehlender Toolchain. Melde
eine Kette nur dann als grün, wenn jeder angeforderte Schritt ein Ergebnis geliefert hat.
