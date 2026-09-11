# CLAUDE.md — Backend (ASP.NET Core, net10.0)

Gilt für `AutomationService/`. Projektzweck, Repository-Layout, Frontend, Prüfkette,
Release und CI stehen in der Wurzel-`CLAUDE.md`.

## Befehle (aus `AutomationService/AutomationService/`)

```powershell
dotnet run                    # API auf http://localhost:5143 (Swagger + Scalar nur in Development)
dotnet build
dotnet test AutomationService.Tests
dotnet test AutomationService.Tests --filter "FullyQualifiedName~RvgFeeCalculatorTests"   # eine Testklasse
```

Zentralruf steuert einen **installierten Systembrowser** (erst Edge, dann Chrome) über
Playwright-Channels; das gebündelte Chromium (`pwsh bin/Debug/net10.0/playwright.ps1 install
chromium`) ist nur der Rückfall, wenn keiner von beiden vorhanden ist.

Der vollständige HTTP-Vertrag (Pfade, DTO-Feldnamen) steht in [`docs/openapi.json`](../docs/openapi.json).

## Vertical Slices

Jedes Feature liegt unter `Features/<Name>/` mit genau zwei Schichten: `Domain/` (`Services` =
Fachlogik, `Persistence` = EF-Entity + Mapping) und `Presentation/` (`Controllers`, `Dtos`,
`DependencyInjection`, dazu je nach Slice `HostedServices`, `Hubs`). Ein dritter Ordner ist nicht
vorgesehen — er umginge die Schnittregeln.

Verdrahtung über je eine `Add…Services`-Erweiterungsmethode, aufgerufen aus `Program.cs`:
`AddLifetimeServices`, `AddPersistenceServices`, `AddWordServices`, `AddPdfConversionServices`,
`AddZentralrufServices`, `AddMailboxServices`, `AddSettingsServices`, `AddMandantenServices`,
`AddVersichererServices`, `AddSachgebieteServices`, `AddRegisterHistorieServices`, `AddVorgaengeServices`,
`AddFormTemplatesServices`, `AddBackupServices`, `AddDevSimulationServices`, `AddEmailVersandServices`.

Options binden aus `appsettings.json` über eine Options-Klasse mit `SectionName`: `WordAutomation`,
`PdfConversion`, `Zentralruf`, `Mailbox`, `EmailVersand`, `Simulation`. Ohne Options-Klasse direkt gelesen:
`Urls`, `Cors:AllowedOrigins` (`Program.cs`), `LegacyImport:*` (`LegacyJsonImportService`) und
`Backup:AutomatischeSicherung` (`BackupInjection`, Not-Aus — Integrationstests setzen ihn `false`).

### Die Slices

- **WordAutomation** — lädt eine `.docx`-Vorlage, ersetzt `{{Platzhalter}}` (DocX/Xceed), füllt die
  Schadensaufstellung und rechnet die RVG-Gebühren (§ 13 RVG: `RvgFeeCalculator`, `RvgPlatzhalter`).
  Meldet unaufgelöste Platzhalter zurück — dieser Vertrag zählt (§4.4). Ausgabe in den Arbeitsordner
  des Vorgangs (`Generated/Arbeit/<Referenz>/`, `ArbeitsVerzeichnis`): immer derselbe Dateiname, eine
  Korrektur ersetzt also die vorige Fassung; nach der Ablage in der Akte löscht das Frontend den
  Ordner (`POST arbeitsordner/aufraeumen`). `WordAutomationWarmupService` lädt den Word-Stack beim
  Start vor und räumt dabei verwaiste Arbeitsordner ab. Vorlagen des
  Anwenders: `%APPDATA%\AutomationService\Vorlagen`; `Templates/` im Projekt ist nur Saatgut
  (`VorlagenSeedService`) und landet komplett in seiner Auswahl — dort keine Testdateien ablegen.
- **ZentralrufAutomation** — (a) Playwright-Vorbefüllung des Online-Formulars, bewusst **headed**,
  damit der Anwalt das Captcha löst und selbst absendet; die Feldselektoren (`anfrageformular-…`)
  sind fest verdrahtet, `tools/ZentralrufDomDump` liest das Live-Formular neu ein. Hier entsteht
  auch die Referenz (`Nr/Jahr Abteilung_Kennzeichen`). (b) Antwort-Parsing
  (`ZentralrufReplyParser`, `POST api/Zentralruf/antwort/parse`; Text oder Base64-`.eml` via
  `ZentralrufReplyEmailExtractor`/MimeKit): Kennzeichen übernehmen, wie sie in der Mail stehen
  (verglichen über `KennzeichenVergleich`, §4.2), Referenz zerlegen,
  Negativantworten/Abweichungen als `warnings` (`ZentralrufReplyWarnings`), Lücken als
  `missingFields`.
- **MailboxMonitor** — ereignisbasierte Postfachüberwachung (MailKit, IMAP IDLE), Filter über den
  Betreff, dieselbe Antwort-Pipeline. Zwei Auth-Wege (`MailboxAuthMethod`) — welcher gilt, hängt
  allein daran, wo das Postfach liegt (`docs/POSTFACH_SETUP.md`): gewöhnliche IMAP-Anmeldung mit
  Passwort (1&1/IONOS, Gmail; auf Platte DPAPI-verschlüsselt, `PasswortSchutz`) oder
  **Microsoft OAuth** für Outlook.com/M365 (`MicrosoftMailOAuthService`, MSAL: interaktive Anmeldung
  über `POST api/Mailbox/microsoft/signin`, verschlüsselter Tokencache
  `%APPDATA%\AutomationService\msal_token_cache.bin`, stilles Erneuern, XOAUTH2 über
  `SaslMechanismOAuth2`; einmalige Azure-App-Registrierung nötig, `Mailbox:MicrosoftClientId`,
  Anleitung `docs/OUTLOOK_SETUP.md`).
  Laufzeitkonfiguration in `%APPDATA%\AutomationService\mailbox_config.json` (`MailboxConfigStore`,
  per ChangeToken heiß nachgeladen), ab Werk aus. Treffer landen im `DbReceivedReplyStore` und gehen
  über den SignalR-Hub `MailboxHub` (`/hubs/mailbox`) an das Frontend. Hängen Dateien an der
  Antwort, legt `AntwortAnhaenge` sie unter `%APPDATA%\AutomationService\Anhaenge\<Schlüssel>` ab
  (§4.3) — der Versand bietet sie zum Anhängen an. Kein Posteingang: aufgehoben wird nur, was an
  einer **erfassten** Antwort hängt.
- **EmailVersand** — versendet die fertig verfasste Mail zum Vorgang (§4.7, `POST
  api/EmailVersand/senden`) oder öffnet sie als Entwurf in Outlook; dazu Versandprotokoll (§4.8),
  Signatur-Übernahme und die Mail-Textvorlagen. Die Einzelheiten — SMTP-Zugang, COM auf dem
  STA-Thread, Anhang-Griff, Signaturbilder, Vorlagen — stehen in
  [`Features/EmailVersand/FALLSTRICKE.md`](AutomationService/Features/EmailVersand/FALLSTRICKE.md).
- **DevSimulation** — Entwickler-Slice (`POST api/Simulation/zentralruf-antwort`): baut einen
  realistischen Antwortmailtext
  (`ZentralrufAntwortMailBuilder`), schickt ihn durch den **echten** Parser, legt ihn im Store ab und
  pusht über `MailboxHub` — für die App nicht von einem IMAP-Treffer unterscheidbar. Hinter
  `Simulation:Enabled` (nur in `appsettings.Development.json` true), sonst 404. Einzige zugelassene
  Ausnahme der Slice-Isolation (darf `MailboxMonitor.Presentation` verwenden).
- **Versicherer** — Wissensbasis über Versicherer (`VersichererWissen`, Tabelle `Versicherer`), aus
  jeder übernommenen Zentralruf-Antwort gefüllt und aktualisiert. Schließt `missingFields`-Lücken
  späterer Antworten; nach außen nur lesend.
- **Sachgebiete** — der Sachgebietskatalog als Stammdaten (§7.1): zwölf Kürzel mit Sachgebiet und
  Rechtsgebiet-Vorschlag, geseedet per `HasData`, gelesen über `GET api/Sachgebiete`
  (`SachgebietKatalog`); dazu `AbteilungKuerzel` (Kürzel ohne Leerzeichen, `C05/3` zerlegen) als
  C#-Gegenstück zur gleichnamigen Dart-Datei. Nur lesend, Pflege in der App ist [S].
- **RegisterHistorie** — das gewachsene Kanzleiregister, jahrgangsweise übernommen (§6.2): `POST
  api/RegisterImport` prüft (Lücken, Doppelte, Spalte 1, Abteilung↔Rechtsgebiet) und schreibt erst
  mit `?uebernehmen=true`; Widersprüche werden benannt, nie berichtigt, abgelehnt nur Dubletten.
  Schlüssel (Jahr, Nummer, Zusatz): `10/19-I` ist eine eigene Akte. `api/RegisterHistorie` gibt
  Stand, berichtigt, löscht (`DELETE {id}`) und nimmt auf (`UebernehmeAsync`: Zeile eines gelöschten
  Vorgangs wird eigenständig, §6.3; `AddRegisterHistorieServices`). Kante nur Vorgaenge →
  RegisterHistorie → Sachgebiete, nie zurück.
- **PdfConversion** — docx→PDF für die Vorschau in der App. Standard-Engine ist Word-COM per Late
  Binding (`WordInteropPdfConversionService`, eigener STA-Thread + Warmup), FreeSpire.Doc ist der
  Rückfall über eine Composite-/Keyed-DI; Engine wählbar in `appsettings`. Dateicache unter
  `Generated/PdfCache` (`PdfPreviewCache`).
- **Vorgaenge** — Lebenszyklus des Vorgangs/Auftrags (Liste, Einzelabruf, Upsert, Löschen,
  Referenzänderung, angefangener Ausfüllstand über `PUT|DELETE api/Vorgaenge/entwurf`).
  `VorgangAbschlussService` schließt ab: Status, Abschlusszeitpunkt und Auftragsnummer in **einer**
  Transaktion, idempotent (§4.8, §7.1); auf den Spiegel wartet er **nicht**.
  `RegisterSpiegelService` schreibt ihn in einen Ordner aus den Einstellungen (§6.2,
  `…/register/export|stand`): `.docx` sofort, PDF über `RegisterPdfNachzug`, gemeldet über
  `RegisterHub`; dazu §6.3 (`RegisterNummern`, `VorgangLoeschung`). Ketten:
  [`docs/DATENFLUESSE.md`](../docs/DATENFLUESSE.md).
- **Mandanten** — Mandantenregister in der Datenbank (CRUD, `MandantNameConflictException` bei
  doppeltem Namen). Die Akten/Fälle im Dateisystem liegen im Frontend, nicht hier. Dazu das
  Paketbuch des Imports (`ImportPakete`, #108).
- **Settings** — Kanzleistammdaten als Einzelsatz (`KanzleiSettingsEntity`), dazu `POST
  api/Settings/auftragsnummer/erhoehe` und die Standardpositionen der Schadensaufstellung (§4.4,
  `GET`/`PUT api/Settings/schadenspositionen`; leere Tabelle = Vorgabe, leeres Speichern setzt
  zurück). Dazu die fünf Ordnerpfade (#103): `AppDatenOrdner` trägt Vorlagen, Register und
  Sicherungen als **abgeleitete** Unterordner (je eine `…Vorgabe`; die Verbraucher hängen daran,
  nicht am Feld), gespeichert wird relativ mit Anker und aufgelöst **nur hier** (`AppOrdnerPfad`);
  `GET api/Settings/ordner` meldet den Zustand.
- **FormTemplates** — benutzerdefinierte Formularvorlagen (Feldbeschreibung zu einer Word-Vorlage),
  CRUD mit Namenskonflikt-Prüfung.
- **Backup** — Export/Import einer Sicherung. `SicherungsArchiv` ist ein ZIP aus `automation.db`
  (per `VACUUM INTO`, WAL-sicher) und `Vorlagen/*.docx`; ältere blanke `.db`-Sicherungen bleiben
  einspielbar. Der Import validiert, sichert den alten Stand daneben und hebt auf den Schemastand.
  Dazu die **Arbeitsplatz-Übergabe** (§7.2, `AutomatischeSicherung`/`ArbeitsplatzAkte`/
  `ArbeitsplatzUebergabe`, `api/Backup/uebergabe`), seit #112 auch `SicherungsZeitgeber` (30 Min,
  nur bei Änderung) und `Aufbewahrungsregel` (Alter statt Anzahl); Kette:
  [`docs/DATENFLUESSE.md`](../docs/DATENFLUESSE.md).

## Core/ — querschnittlich, kein Slice

`Core/Lifetime` — Health-Endpunkt (`MapHealthEndpoint`: 503 `startet`, bis `ApplicationReadiness`
meldet, dann 200 `bereit`), `Programmfassung` und `ParentProcessWatchdog`. Der Wächter wird **nur**
registriert, wenn `--parent-pid` übergeben wurde; ohne das Argument (`dotnet run`) läuft der Dienst
eigenständig. Kein `UseHttpsRedirection`: der Dienst spricht bewusst nur lokales HTTP.
`Core/Ablage` — `AtomareAblage` legt eine fertige Datei so ab, dass ein Beobachter des Ordners sie
nie halbfertig sieht (woanders bauen, dann umbenennen): Register-Spiegel und automatische Sicherung.

## Persistenz

EF Core auf eingebettetem SQLite: `AutomationDbContext` über
`%APPDATA%\AutomationService\automation.db` (Pfade zentral in `AppDataPaths`). Das Backend ist
**alleiniger Eigentümer** der Datei — das Frontend hat keine eigene Persistenz und greift
ausschließlich über HTTP zu; das schließt die früheren Lost-Update-Races der parallel schreibenden
JSON-Speicher aus. Der Context bündelt zwingend alle `DbSet<>` (EF erlaubt keinen verteilten
Context), das Schema-Mapping liegt aber je beim Slice (`IEntityTypeConfiguration`, eingesammelt per
`ApplyConfigurationsFromAssembly`). Migrationen unter `Core/Persistence/Migrations` laufen beim
Start (`DatabaseMigrationService`, danach `LegacyJsonImportService`; Hosted Services starten in
Registrierungsreihenfolge).

## Tests

Das Testprojekt liegt *innerhalb* des Web-Projektordners (`AutomationService.Tests/`). Die
`Compile`/`Content`/`None Remove`-Einträge in `AutomationService.csproj` halten das Web-SDK davon
ab, es mitzuziehen — **nicht entfernen**.

Gliederung: `Unit/` (Fachlogik ohne Host), `Integration/` (über `WebApplicationFactory<Program>`:
Health, WordAutomation-Controller, HTTP-Vertrag), `Support/` (Helfer: `RepoWurzel`,
`FakeHostEnvironment`, `WordVorlagenUmgebung`, `TestAppDataUmgebung`), `Architecture/` (ausführbare
Regeln; Grundlage sind `CsQuelldateien`/`Quelldatei`, die Pfad, Namespace und `using`s der
handgeschriebenen Quellen lesen).

Welche Regel welcher Test erzwingt, steht **einmal** in der Wurzel-`CLAUDE.md` („Diese Regeln sind
ausführbar") — Dateilänge, Namespace, Schnittregeln, HTTP-Vertrag, Doku und Anforderungsverweise mit
ihren `Architecture/`- und `Integration/`-Klassen. Nur hier zuhause und dort nicht aufgeführt:
`Unit/LifetimeInjectionTests.cs` — der Watchdog wird ausschließlich mit `--parent-pid` registriert.

Schlägt eine dieser Regeln fehl, ist die Antwort **nie**, die Regel zu lockern oder das Limit
hochzusetzen. Eine begründete Ausnahme gehört namentlich in den jeweiligen Test.
