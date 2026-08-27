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
`AddVersichererServices`, `AddVorgaengeServices`, `AddFormTemplatesServices`, `AddBackupServices`,
`AddDevSimulationServices`, `AddEmailVersandServices`.

Options binden aus `appsettings.json` über eine Options-Klasse mit `SectionName`: `WordAutomation`,
`PdfConversion`, `Zentralruf`, `Mailbox`, `EmailVersand`, `Simulation`. Ohne Options-Klasse direkt gelesen:
`Urls`, `Cors:AllowedOrigins` (`Program.cs`) und `LegacyImport:*` (`LegacyJsonImportService`).

### Die Slices

- **WordAutomation** — lädt eine `.docx`-Vorlage, ersetzt `{{Platzhalter}}` (DocX/Xceed), füllt die
  Schadensaufstellung und rechnet die RVG-Gebühren (`RvgFeeCalculator`, Geschäftsgebühr § 13 RVG).
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
  `ZentralrufReplyEmailExtractor`/MimeKit): Kennzeichen normalisieren, Referenz zerlegen,
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
- **EmailVersand** — versendet die fertig verfasste Mail zum Vorgang (§4.7, `POST api/EmailVersand/senden`,
  `GET api/EmailVersand/bereitschaft`). Sendet per SMTP über **denselben** Zugang, den auch der
  `MailboxMonitor` nutzt (`SmtpZugang.Aus` leitet den Postausgang aus dem Posteingang ab;
  `EmailVersand:SmtpHost` in appsettings überschreibt). Alles oder nichts: Zugang, Anhänge und
  Adressen werden geprüft, **bevor** verbunden wird (`AnhangPruefung`, `EmailNachrichtBauer`) —
  ein Fehler heißt, dass nichts hinausgegangen ist. Danach trägt `GesendetOrdnerAblage` die
  Nachricht per IMAP in "Gesendet" nach, außer der Anbieter tut es selbst (Gmail).
  Zweiter Weg statt Versand: `POST api/EmailVersand/entwurf` öffnet die Nachricht als Entwurf in
  Outlook, sonst als `.eml` (`EntwurfDatei`); `EntwurfOeffner` entscheidet. `OutlookVerbindung` hält
  dafür COM per **Late Binding** (wie bei Word, kein PIA) auf einem **dauerhaften** STA-Thread und
  lässt die Instanz leben — sonst kostet jeder Entwurf den Outlook-Kaltstart;
  `POST api/EmailVersand/entwurf/vorwaermen` bezahlt ihn, während der Anwalt tippt.
  `GET api/EmailVersand/outlook/anhaenge` holt die Anhänge der in Outlook offenen Nachricht
  (`OutlookAuswahl`) — der Ersatz für das Ziehen von Anhang zu Anhang. Dort setzt Outlook seine eigene Signatur —
  deshalb hängt `KanzleiSignatur` die aus den Einstellungen **nur** beim Direktversand an.
  `GET api/EmailVersand/signaturen` liest die in Outlook eingerichteten Signaturen
  (`%APPDATA%\Microsoft\Signatures\*.txt`) zum einmaligen Übernehmen.
- **DevSimulation** — Entwickler-Slice (`POST api/Simulation/zentralruf-antwort`): baut einen
  realistischen Antwortmailtext
  (`ZentralrufAntwortMailBuilder`), schickt ihn durch den **echten** Parser, legt ihn im Store ab und
  pusht über `MailboxHub` — für die App nicht von einem IMAP-Treffer unterscheidbar. Hinter
  `Simulation:Enabled` (nur in `appsettings.Development.json` true), sonst 404. Einzige zugelassene
  Ausnahme der Slice-Isolation (darf `MailboxMonitor.Presentation` verwenden).
- **Versicherer** — Wissensbasis über Versicherer (`VersichererWissen`, Tabelle `Versicherer`), aus
  jeder übernommenen Zentralruf-Antwort gefüllt und aktualisiert. Schließt `missingFields`-Lücken
  späterer Antworten; nach außen nur lesend.
- **PdfConversion** — docx→PDF für die Vorschau in der App. Standard-Engine ist Word-COM per
  Late Binding (`WordInteropPdfConversionService`, eigener STA-Thread + Warmup), FreeSpire.Doc ist
  der Rückfall über eine Composite-/Keyed-DI; Engine wählbar in `appsettings`. Dateicache unter
  `Generated/PdfCache` (`PdfPreviewCache`).
- **Vorgaenge** — Lebenszyklus des Vorgangs/Auftrags (Liste, Einzelabruf, Upsert, Löschen,
  Referenzänderung). `VorgangAbschlussService` schließt ab: Status, Abschlusszeitpunkt und das
  Hochzählen der laufenden Auftragsnummer in **einer** Transaktion, idempotent (§4.8, §7.1).
- **Mandanten** — Mandantenregister in der Datenbank (CRUD, `MandantNameConflictException` bei
  doppeltem Namen). Die Akten/Fälle im Dateisystem liegen im Frontend, nicht hier.
- **Settings** — Kanzleistammdaten als Einzelsatz (`KanzleiSettingsEntity`), dazu
  `POST api/Settings/auftragsnummer/erhoehe` für die laufende Auftragsnummer.
- **FormTemplates** — benutzerdefinierte Formularvorlagen (Feldbeschreibung zu einer Word-Vorlage),
  CRUD mit Namenskonflikt-Prüfung.
- **Backup** — Export/Import einer Sicherung. `SicherungsArchiv` ist ein ZIP aus `automation.db`
  (per `VACUUM INTO`, WAL-sicher) und `Vorlagen/*.docx`; ältere blanke `.db`-Sicherungen bleiben
  einspielbar. Der Import validiert, sichert den alten Stand daneben und hebt auf den Schemastand.

## Core/ — querschnittlich, kein Slice

`Core/Lifetime` — Health-Endpunkt (`MapHealthEndpoint`: 503 `startet`, bis `ApplicationReadiness`
meldet, dann 200 `bereit`) und `ParentProcessWatchdog`. Der Wächter wird **nur** registriert, wenn
`--parent-pid` übergeben wurde; ohne das Argument (`dotnet run`) läuft der Dienst eigenständig.
Kein `UseHttpsRedirection`: der Dienst spricht bewusst nur lokales HTTP.

## Persistenz

EF Core auf eingebettetem SQLite: `AutomationDbContext` über
`%APPDATA%\AutomationService\automation.db` (Pfade zentral in `AppDataPaths`). Das Backend ist
**alleiniger Eigentümer** der Datei — das Frontend hat keine eigene Persistenz und greift
ausschließlich über HTTP zu; das schließt die früheren Lost-Update-Races der parallel schreibenden
JSON-Speicher aus. Der Context bündelt zwingend alle `DbSet<>` (EF erlaubt keinen verteilten
Context), das Schema-Mapping liegt aber je beim Slice (`IEntityTypeConfiguration`, eingesammelt per
`ApplyConfigurationsFromAssembly`). Migrationen unter `Core/Persistence/Migrations` laufen beim Start
(`DatabaseMigrationService`, danach `LegacyJsonImportService`; Hosted Services starten in
Registrierungsreihenfolge).

## Tests

Das Testprojekt liegt *innerhalb* des Web-Projektordners (`AutomationService.Tests/`). Die
`Compile`/`Content`/`None Remove`-Einträge in `AutomationService.csproj` halten das Web-SDK davon
ab, es mitzuziehen — **nicht entfernen**.

Gliederung: `Unit/` (Fachlogik ohne Host), `Integration/` (über `WebApplicationFactory<Program>`:
Health, WordAutomation-Controller, HTTP-Vertrag), `Support/` (Helfer: `RepoWurzel`,
`FakeHostEnvironment`, `WordVorlagenUmgebung`), `Architecture/` (ausführbare Regeln; Grundlage sind
`CsQuelldateien`/`Quelldatei`, die Pfad, Namespace und `using`s der handgeschriebenen Quellen lesen).

| Regel | Erzwungen von |
|---|---|
| ≤ 300 Zeilen je Datei (Richtwert 250; `bin/`, `obj/`, `Migrations/` ausgenommen) | `Architecture/DateilaengeTests.cs` |
| Jede Quelldatei deklariert einen Namespace; Namespace == Ordnerpfad | `Architecture/NamespaceKonventionTests.cs` |
| Domain ohne eigene Presentation und ohne ASP.NET MVC; kein Zugriff auf fremde Presentation; nur die Schichten Domain/Presentation | `Architecture/SliceIsolationTests.cs` |
| HTTP-Vertrag == `docs/openapi.json` | `Integration/OpenApiVertragTests.cs` |
| Watchdog nur mit `--parent-pid` | `Unit/LifetimeInjectionTests.cs` |
| Jeder Slice und jede `Add…Services`-Methode steht in dieser Datei | `Architecture/DokumentationTests.cs` |
| Anforderungsverweise (`§4.8`, nie `Req. …`) gegen `docs/ANFORDERUNGEN_INDEX.md` | `Architecture/DokumentationTests.cs` |

Schlägt eine dieser Regeln fehl, ist die Antwort **nie**, die Regel zu lockern oder das Limit
hochzusetzen. Eine begründete Ausnahme gehört namentlich in den jeweiligen Test.
