# Automation_App — Übersicht

Windows-Desktop-App für die Verkehrsunfall-Mandate einer Einzelkanzlei:
Zentralruf-Anfrage → Antwort auswerten → Anspruchsschreiben (inkl. RVG-Berechnung)
erzeugen → prüfen, ablegen, versenden.

Verbindliches Anforderungsdokument: **[REQUIREMENTS.md](REQUIREMENTS.md)** —
vor jeder Änderung am Workflow-Verhalten lesen.
Arbeitsanweisungen für AI-Agents: **[CLAUDE.md](CLAUDE.md)**.

## Repo-Aufteilung

Das Projekt liegt in **drei** Repositories. Dieses hier ist das Wurzel-Repo und
enthält nur die übergreifenden Dokumente sowie die Hilfsprogramme:

| Repo | Inhalt |
|---|---|
| dieses (`Automation_App`) | REQUIREMENTS.md, CLAUDE.md, `docs/`, `tools/`, `Beispiele/` |
| [`AutomationService`](https://github.com/Romanahmad32/AutomationService) | ASP.NET-Core-Backend (net10.0), Port 5143 |
| [`flutter_automation_app`](https://github.com/Romanahmad32/flutter_automation_app) | Flutter-Desktop-Frontend |

Frontend und Backend werden lokal als Unterordner ausgecheckt und sind hier
per `.gitignore` ausgeschlossen — sie sind **keine** Submodule.

```
Automation_App/                 <- dieses Repo
├── AutomationService/          <- eigenes Repo (ignoriert)
├── Automation_App_Frontend/    <- eigenes Repo (ignoriert)
├── Beispiele/                  <- anonymisierte Testdaten + Word-Vorlagen
├── docs/
└── tools/
```

> **Wichtig bei Änderungen am API-Vertrag:** Da Frontend und Backend getrennte
> Repos sind, lässt sich eine Vertragsänderung nicht in einem Commit abbilden.
> Ein DTO-Feld umzubenennen bricht das Frontend still zur Laufzeit. Deshalb
> beide Seiten immer gemeinsam ändern und die Testsuites beider Repos laufen
> lassen.

## Datenschutz

Es gehören **keine** echten Mandantendaten in eines der Repos (DSGVO,
§ 203 StGB). `Beispiele/Anwortemail von Zentralruf.txt` ist eine
**anonymisierte** Fassung einer echten Zentralruf-Antwort: Kennzeichen,
Versicherungsschein-Nummer und Kanzleiblock sind durch Platzhalter ersetzt,
Struktur und Formatierung sind unverändert, damit der Parser realistisch
getestet wird. Generierte Schreiben (`Generated/`) und Aktenordner sind
ausgeschlossen.

## Hilfsprogramme (`tools/`)

| Tool | Zweck |
|---|---|
| `TemplateParametrizer` | Word-Vorlagen mit `{{Platzhaltern}}` versehen |
| `ZentralrufDomDump` | DOM des Zentralruf-Formulars ausgeben, wenn die Selektoren brechen |
