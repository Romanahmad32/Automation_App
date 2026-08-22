# CLAUDE.md

Wegweiser für Claude Code (claude.ai/code). **Diese Datei wird bei jeder Sitzung vollständig
geladen und bleibt deshalb kurz** — sie sagt, was das Projekt ist, wo etwas liegt und was
unverhandelbar gilt. Alles Weitere wird bei Bedarf nachgeladen:

- `Automation_App_Frontend/CLAUDE.md` und `AutomationService/CLAUDE.md` ziehen sich selbst,
  sobald im jeweiligen Teilbaum gearbeitet wird.
- Die Tabelle unter „Bevor du anfängst" sagt, welches Dokument welche Aufgabe abdeckt.

Wer hier etwas ergänzt, prüft zuerst, ob es nicht in eine dieser Dateien gehört.

## Was das ist

Windows-Desktop-App für einen deutschen Einzelanwalt. Sie automatisiert den Ablauf bei
Verkehrsunfall-Mandaten: Anfrage beim Zentralruf der Autoversicherer nach dem gegnerischen
Versicherer, Füllen der Word-Anspruchsschreiben (inkl. RVG-Gebühren), dann Prüfen, Ablegen,
Versenden. Oberfläche, erzeugte Dokumente, Fachbegriffe und viele Kommentare sind deutsch —
diese Konvention beibehalten.

**`REQUIREMENTS.md` im Wurzelverzeichnis ist das bindende Anforderungsdokument** — vor jeder
Änderung am fachlichen Ablauf lesen. Sie ist **absichtlich nicht versioniert** (`.gitignore`):
sie enthält Kanzlei-Interna, das Repo ist öffentlich. In einem frischen Clone, einem Worktree
oder einer Cloud-Sitzung liegt sie deshalb nicht vor. Wer dort an Workflow-Verhalten arbeitet
und die Datei nicht sieht, **fragt nach, statt die Anforderung zu raten** — CLAUDE.md
beschreibt, wie gebaut wird, nicht was fachlich gefordert ist.

Bewusste Haltepunkte für den Menschen (nicht wegautomatisieren): Captcha im Zentralruf-Formular,
Sichtprüfung des Dokuments, Freigabe des Versands.

Auslieferungsziel — ein Klick aufs App-Symbol startet Frontend und Backend zusammen als eine
gewöhnliche Windows-Anwendung, kein separater Serverstart, kein Terminal. **Das ist erreicht:**
`AppBootstrap` (`lib/core/backend/`) startet den Dienst als Kindprozess, `ParentProcessWatchdog`
beendet ihn wieder.

Fachliche Konvention: Kfz-Kennzeichen mit Bindestrich, z. B. `HG-E 1427`
(Unterscheidungszeichen-Erkennungsbuchstaben Nummer) — in Hinweisen, Prüfungen und erzeugten
Dokumenten.

## Bevor du anfängst — was lesen?

| Du willst … | Lies zuerst |
|---|---|
| einen Endpunkt hinzufügen oder ändern | Skill `neuer-endpunkt` — lädt sich selbst; sonst `.claude/skills/neuer-endpunkt/SKILL.md` |
| wissen, welche Felder ein Endpunkt hat | [`docs/openapi.json`](docs/openapi.json) — nicht die Controller greppen |
| an einem Feature arbeiten | `Automation_App_Frontend/lib/features/<feature>/FEATURE.md` |
| am Flutter-Frontend arbeiten | `Automation_App_Frontend/CLAUDE.md` |
| am Backend arbeiten | `AutomationService/CLAUDE.md` |
| an Prozessstart, Pfaden, Vorlagen, Sicherung, Versionierung, CI, Installer arbeiten | [`docs/RELEASE.md`](docs/RELEASE.md) |
| fachliches Verhalten ändern | `REQUIREMENTS.md`; fehlt sie, sagt [`docs/ANFORDERUNGEN_INDEX.md`](docs/ANFORDERUNGEN_INDEX.md), wonach zu fragen ist |
| wissen, was gebaut ist und was fehlt | [`docs/STAND.md`](docs/STAND.md) |
| das Postfach an Outlook/M365 anbinden | [`docs/OUTLOOK_SETUP.md`](docs/OUTLOOK_SETUP.md) |

## Landkarte

```
Automation_App/                  ← dieser Ordner IST das Git-Repo (Romanahmad32/Automation_App,
├── AutomationService/             öffentlich, Standardzweig master). Frontend und Backend sind
│   └── AutomationService/         Unterordner, damit eine Vertragsänderung über beide Seiten
├── Automation_App_Frontend/       ein Commit und ein Diff ist.
├── Beispiele/                   echte Beispieldaten (`VORLAGE *.docx`, Zentralruf-Antwortmail),
│                                  nicht versioniert — im frischen Clone nicht vorhanden
├── docs/                        Verträge, Anleitungen, Stand
├── installer/                   Inno-Setup-Skript
├── scripts/                     check.ps1 und Releasehelfer
├── tools/                       TemplateParametrizer, ZentralrufDomDump (eigenständige .NET-Konsolen)
└── .claude/                     geteiltes Agent-Setup: Rechte, Hooks, Slash-Befehle
```

Das Backend lauscht auf `http://localhost:5143` (net10.0, SignalR für die Postfach-Meldungen).
CI: `.github/workflows/ci.yml`; Auslieferung läuft über Git-Tags
(`git tag v1.2.0 && git push origin v1.2.0`, Einzelheiten in [`docs/RELEASE.md`](docs/RELEASE.md)).
Die Toolchain ist festgenagelt (`global.json`, `FLUTTER_VERSION`); ein Versionssprung gehört in
einen eigenen Commit.

Ein Fachthema, zwei Orte — die Zuordnung Feature ↔ Slice:

| Tab | Frontend `lib/features/` | Backend `Features/` |
|---|---|---|
| 0 Übersicht | `dashboard` (nur lesend, springt in den zuständigen Tab) | — |
| 1 Vorgang starten | `vorgang_starten`, `zentralruf_request` | `Vorgaenge`, `ZentralrufAutomation` |
| 2 Postfach | `mailbox`, `zentralruf_reply`, `versicherer` | `MailboxMonitor`, `ZentralrufAutomation`, `Versicherer` |
| 3 Word Automation | `word_automation` | `WordAutomation`, `PdfConversion` |
| 4 Vorlagen Verwalten | `form_template_setup` | `FormTemplates` |
| 5 Mandanten | `mandanten` | `Mandanten` |
| 6 Register | `vorgaenge` (Registeransicht) | `Vorgaenge` |
| 7 Vorgänge | `vorgaenge` | `Vorgaenge` |
| 8 Einstellungen | `settings`, `backup` | `Settings`, `Backup` |
| — (nur Debug) | `dev_simulation` | `DevSimulation` |

Die Tab-Indizes liegen zentral in `lib/core/router/app_tab_index.dart` (`AppTabIndex`); beim
Umsortieren dort **und in dieser Tabelle** mitpflegen. **Index 0 ist der Start-Tab** — was dort
steht, sieht der Anwalt direkt nach dem Öffnen.

## Architektur in Kürze

Das Frontend spricht über HTTP mit dem Backend (Dio; Host und Port kommen aus `BackendEndpoint`
in `lib/core/backend/backend_endpoint.dart` — die einzige Quelle für beides, nie wieder fest
eintragen). Das Backend erledigt, was Flutter nicht kann: Word-Dokumente und Browsersteuerung.

**Der vollständige HTTP-Vertrag steht in [`docs/openapi.json`](docs/openapi.json)** — Pfade,
DTOs, Feldnamen. Die Datei wird nicht von Hand gepflegt: `OpenApiVertragTests` holt sie aus dem
laufenden Dienst und schlägt an, wenn der Bestand abweicht. Beide Seiten sind nur über
Zeichenketten verbunden (Pfade, camelCase-Feldnamen), deshalb prüft
`test/architecture/http_vertrag_test.dart` die Dart-Seite gegen dieselbe Datei.

Backend: senkrechte Schnitte je Feature. Frontend: Clean Architecture je Feature. Das Frontend
hat **keine** eigene Persistenz — alles liegt in der SQLite-Datenbank des Backends. Einzelheiten
stehen in den beiden Teilbaum-Dateien.

## Prüfkette

```powershell
./scripts/check.ps1            # alles; -NurFrontend / -NurBackend für Teilläufe
```

Fährt genau die Schritte aus `.github/workflows/ci.yml`, bricht nicht beim ersten Fehler ab und
fasst am Ende zusammen. **Vor dem Abschließen einer Änderung laufen lassen** — die Einzelbefehle
für die Arbeit dazwischen stehen in den Teilbaum-Dateien.

## Regeln, die nicht verhandelbar sind

Für jeden Menschen **und jeden AI-Agent**, der hier Code ändert:

- **Dateien kurz halten.** Nicht generierte Code-Dateien max. **250** Zeilen, in Ausnahmefällen
  bis **300**. Wird eine Datei länger, in mehrere Klassen/Widgets aufteilen.
- **Keine privaten Typen oder Top-Level-Funktionen** im Frontend (kein `_`-Präfix bei Klassen,
  keine privaten `_WidgetXyz`) — stattdessen eigenständige, öffentliche, wiederverwendbare
  Bausteine in eigenen Dateien. (State-Klassen von `StatefulWidget` sind die übliche Ausnahme.)
- **Vorhandenes bevorzugen.** Vor jedem neuen Baustein prüfen, ob es schon einen passenden gibt,
  und diesen verwenden oder erweitern statt zu verdoppeln.
- Benennung von Datasources und Repositories: siehe `Automation_App_Frontend/CLAUDE.md`.

Diese Regeln sind **ausführbar** — wer eine verletzt, bekommt einen roten Test statt eines
übersehenen Hinweises:

| Regel | Erzwungen von |
|---|---|
| Dateilänge ≤ 300 Zeilen | `test/architecture/file_length_test.dart`, `Architecture/DateilaengeTests.cs` |
| Keine privaten Typen/Top-Level-Funktionen | `test/architecture/private_typen_test.dart` |
| Benennung von Datasources/Repositories | `test/architecture/benennung_test.dart` |
| Schichten (Clean Architecture / senkrechte Schnitte) | `test/architecture/clean_architecture_test.dart`, `Architecture/SliceIsolationTests.cs` |
| Namespace = Ordnerpfad | `Architecture/NamespaceKonventionTests.cs` |
| HTTP-Vertrag Frontend ↔ Backend | `Integration/OpenApiVertragTests.cs`, `test/architecture/http_vertrag_test.dart` |
| Doku: Steckbrief je Feature, Zeilenbudgets, lebende Verweise | `test/architecture/dokumentation_test.dart`, `Architecture/DokumentationTests.cs` |
| Anforderungsverweise (`§4.8`) gegen `docs/ANFORDERUNGEN_INDEX.md` | `test/architecture/anforderungen_test.dart`, `Architecture/DokumentationTests.cs` |
| Formatierung | `dart format --set-exit-if-changed`, `dotnet format --verify-no-changes` (CI) |
| Generierter Stand aktuell | build_runner + `git diff --exit-code` (CI) |
| `pubspec.lock` passt zur gepinnten Flutter-Fassung | `pub get` + `git diff --exit-code` (CI, `check.ps1`) |

Schlägt eine davon fehl, ist die Antwort **nie**, die Regel zu lockern oder das Limit
hochzusetzen. Begründete Ausnahmen gehören namentlich in den jeweiligen Test.

## Agent-Setup (`.claude/`)

Versioniert, damit jeder Agent dieselbe Umgebung vorfindet — hier, im Worktree, in der Cloud:

- **`settings.json`** — Rechte und Hooks. Die Routinebefehle der Toolchain (`flutter`, `dart`,
  `dotnet`, `git`) laufen ohne Rückfrage; die auswärts wirkenden bzw. schwer umkehrbaren
  Git-Befehle (`push`, `reset --hard`, `clean`, `rebase`, `checkout --`) fragen nach.
- **`hooks/dart-format.ps1`** — läuft nach jedem Edit/Write an einer `.dart`-Datei und formatiert
  sie. Grund: die CI prüft die Backend-Formatierung, für Dart gibt es keine solche Prüfung — ohne
  den Hook sammelt sich Formatierungsrauschen in den Diffs und verdeckt die eigentliche Änderung.
  Generierte Dateien lässt er aus, und er schweigt in jedem Fehlerfall (ein Formatierer, der eine
  Werkzeugausführung abbricht, kostet mehr als er einbringt).
- **`commands/`** — auf Zuruf: `/pruefen` (komplette Prüfkette, dieselben Schritte wie die CI),
  `/generieren` (build_runner + was danach zu prüfen ist).
- **`skills/`** — zieht sich selbst, wenn die Aufgabe passt: `neuer-endpunkt` (das Rezept für
  einen neuen oder geänderten HTTP-Endpunkt über beide Seiten). Der Unterschied zu `commands/`:
  ein Skill braucht niemanden, der ihn aufruft — genau das, was ein Agent mit frischem Kontext
  nicht weiß.

Maschinenlokales gehört in `.claude/settings.local.json` — die bleibt ignoriert.
