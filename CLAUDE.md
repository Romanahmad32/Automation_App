# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Windows desktop app for a German solo lawyer that automates the claims workflow for traffic-accident
mandates (Verkehrsunfall-Mandate): query the Zentralruf der Autoversicherer for the opposing insurer,
fill Word claim-letter templates (incl. RVG fee calculation), then review/file/send. **`REQUIREMENTS.md`
at the repo root is the binding requirements document — read it before changing workflow behavior.**
UI, generated documents, domain terms, and many code comments are German; keep that convention.

Deliberate human-in-the-loop points (do not automate away): captcha solving on the Zentralruf form,
visual document review, and send approval.

Deployment goal: the finished product must ship as a single app that the lawyer launches with one
click on the app icon — frontend and backend start together and run as one ordinary Windows app
(no separate "start the server" step, no terminal). Keep this in mind when wiring process startup,
installer, and paths.

Domain convention: Kfz-Kennzeichen are written with a hyphen, e.g. `HG-E 1427`
(Unterscheidungszeichen-Erkennungsbuchstaben Nummer). Use this format in UI hints,
validation, and generated documents.

## Repository layout

- `AutomationService/AutomationService/` — ASP.NET Core (net10.0) backend, listens on `http://localhost:5143` (SignalR enabled for mailbox push)
- `Automation_App_Frontend/` — Flutter desktop frontend (Windows is the real target)
- `tools/TemplateParametrizer`, `tools/ZentralrufDomDump` — standalone .NET console helpers
- `Beispiele/` — real sample data: Word templates (`VORLAGE *.docx`) and a Zentralruf reply email
- This root folder is **not** a git repository.

## Commands

### Backend (run from `AutomationService/AutomationService/`)

```powershell
dotnet run                    # starts API on http://localhost:5143 (Swagger + Scalar in Development)
dotnet build
dotnet test AutomationService.Tests
dotnet test AutomationService.Tests --filter "FullyQualifiedName~RvgFeeCalculatorTests"   # single test class
```

The Zentralruf feature drives an installed system browser (Edge, then Chrome) via Playwright
channels; the bundled Chromium (`pwsh bin/Debug/net10.0/playwright.ps1 install chromium`) is only
a fallback when neither is installed.

### Frontend (run from `Automation_App_Frontend/`)

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate after editing DI/routes/freezed/json classes
flutter run -d windows
flutter test
flutter analyze
```

Files ending in `.g.dart`, `.freezed.dart`, `.gr.dart`, and `injection.config.dart` are generated —
never edit them by hand; run build_runner instead.

## Architecture

The frontend talks to the backend over HTTP (Dio, base URL hardcoded to `http://localhost:5143` in
`lib/core/network/network_module.dart`). The backend does the heavy lifting that Flutter can't:
Word document manipulation and browser automation.

### Backend: vertical slices

Each feature lives under `Features/<Name>/` split into `Domain/Services` (logic) and `Presentation`
(Controllers, Dtos, DependencyInjection). Feature wiring happens via extension methods
(`AddWordServices`, `AddZentralrufServices`) called from `Program.cs`; options bind from
`appsettings.json` sections (`WordAutomation`, `Zentralruf`).

- **WordAutomation** — loads a `.docx` template, replaces `{{Placeholder}}` patterns (DocX/Xceed
  library), fills the damage-listing table, and computes RVG attorney fees (`RvgFeeCalculator`,
  Geschäftsgebühr per § 13 RVG). Reports unresolved placeholders back to the caller — that contract
  matters (requirement 3.4). Templates live in `Templates/`, output goes to `Generated/` (or a
  caller-supplied output directory). A warmup hosted service pre-loads the Word stack at startup.
- **ZentralrufAutomation** — two parts. (a) Playwright-driven prefill of the Zentralruf online form:
  the browser runs **headed** so the lawyer can solve the captcha and submit manually; the service
  only prefills and returns lists of filled/skipped fields. Form field IDs are hardcoded selectors
  (`anfrageformular-…`); use `tools/ZentralrufDomDump` to re-inspect the live form when they break.
  The Referenz string format (`Nr/Jahr Abteilung_Kennzeichen`) is built here. (b) Reply parsing
  (`ZentralrufReplyParser`, `POST api/Zentralruf/antwort/parse`): extracts the opposing-insurer data
  from the answer mail (text or Base64 `.eml` via `ZentralrufReplyEmailExtractor`/MimeKit), normalises
  the Kfz-Kennzeichen, splits the Referenz into parts, flags negative answers and mismatches as
  `warnings`, and reports `missingFields`. Warning logic is shared via `ZentralrufReplyWarnings`.
- **MailboxMonitor** — event-based inbox watch (MailKit IMAP IDLE) that catches Zentralruf answers
  by subject filter and runs them through the same reply pipeline. Two auth paths (`MailboxAuthMethod`):
  Gmail app-password, or **Microsoft OAuth** for Outlook.com/M365 mailboxes (Microsoft killed IMAP
  basic auth in Sept 2024) — `MicrosoftMailOAuthService` (MSAL, interactive browser sign-in via
  `POST api/Mailbox/microsoft/signin`, encrypted token cache in `%APPDATA%\AutomationService\msal_token_cache.bin`,
  silent refresh, XOAUTH2 via `SaslMechanismOAuth2`). Requires a one-time Azure app registration by
  the developer (`Mailbox:MicrosoftClientId` in appsettings.json; guide: `docs/OUTLOOK_SETUP.md`).
  Runtime config in `%APPDATA%\AutomationService\mailbox_config.json` (`MailboxConfigStore`,
  hot-reloaded via ChangeToken); disabled by default so it stays inert without credentials. Hits land
  in an in-memory `ReceivedReplyStore` and are pushed to the frontend over the `MailboxHub` SignalR hub.
- **DevSimulation** — developer-only simulation of the workflow: `POST api/Simulation/zentralruf-antwort`
  builds a realistic reply-mail text (`ZentralrufAntwortMailBuilder`), runs it through the **real**
  `ZentralrufReplyParser`, stores it in the `ReceivedReplyStore` and pushes over `MailboxHub` — for the
  app indistinguishable from a real IMAP hit. Gated by `Simulation:Enabled` (true only in
  appsettings.Development.json; otherwise 404). Frontend counterpart: `dev_simulation` feature —
  „Demo-Vorgang"-Button + per-Vorgang Simulations-Menü in „Vorgänge verwalten", visible only in
  `kDebugMode` (debug builds).
- **Versicherer** — insurer knowledge base (`Versicherer` table), auto-filled/updated from every
  taken-over Zentralruf reply (`VersichererWissen`). Used to fill gaps when a reply has
  `missingFields` and as groundwork for the deferred recipient logic (§9).
- **PdfConversion** — docx→PDF conversion for in-app preview. Default engine is **Word COM late-binding**
  (`WordInteropPdfConversionService`, dedicated STA thread + warmup; FreeSpire.Doc is the fallback via
  a Composite/keyed DI, engine selectable in `appsettings`). File cache under `Generated/PdfCache`.

The test project sits *inside* the web project folder (`AutomationService.Tests/`); the `.csproj`
contains explicit `Compile/Content Remove` entries to keep the SDK from ingesting it — don't remove those.

### Frontend: Clean Architecture per feature

Each feature under `lib/features/` follows `data/` (datasources, repository impls) → `domain/`
(entities, repository interfaces, usecases) → `presentation/` (blocs, pages, views, widgets).
State management is flutter_bloc; DI is get_it + injectable (annotations + generated config);
navigation is auto_route (routes declared in `lib/core/router/app_router.dart`); forms use
reactive_forms.

Features: `vorgang_starten` (capture mandate data + start the Zentralruf request, creating a
`Vorgang`), `word_automation` (3-step wizard: template fill → review → save, + PDF preview/edit,
closes the Vorgang), `zentralruf_request`, `zentralruf_reply` (paste/upload answer mail → parse →
autofill the template; matches replies to a Vorgang by Referenz, with a confirm-first fallback
match over Gegner-Kennzeichen + Unfalldatum flagged as `zuordnungVermutet`), `mailbox` (status +
inbox for the monitored mailbox), `mandanten` (client register + filesystem Akten/Fälle),
`versicherer` (read access to the backend insurer knowledge base), `vorgaenge` (Vorgang
lifecycle management + the Sachgebiete/Auftrag register view), `form_template_setup` (user-defined
form templates describing a Word template's fields), `backup` (data backup/restore), `settings`
(Kanzlei data, mailbox access, Aktenstammordner, laufende Auftragsnummer/Abteilung, appearance).
The frontend holds **no** local persistence: every store now goes through the backend over HTTP
(`api_*` datasources) and lands in the backend's SQLite database — the former JSON stores
(`kanzlei_settings.json`, `mandanten.json`, …) are gone. Navigation is a left **sidebar**
(`AppSidebar`/`AppShellPage`), ordered: 0 Vorgang starten, 1 Postfach, 2 Word Automation,
3 Vorlagen Verwalten, 4 Mandanten, 5 Register, 6 Vorgänge, 7 Einstellungen — die Tab-Indizes
liegen zentral in `lib/core/router/app_tab_index.dart` (`AppTabIndex`); beim Umsortieren dort
mitpflegen.

## Code-Qualität & Wartbarkeit (verbindlich)

Diese Regeln gelten projektweit (Schwerpunkt Flutter-Frontend) und sind von jedem Menschen **und
jedem AI-Agent** einzuhalten, der Code in diesem Repo ändert:

- **Dateien kurz halten.** Code-Dateien (keine generierten Dateien) max. **250 Zeilen**, in
  Ausnahmefällen bis **300**. Wird eine Datei länger, in mehrere Widgets/Klassen aufteilen.
- **Keine privaten Funktionen/Klassen** (kein `_`-Prefix bei Klassen/Top-Level-Funktionen, keine
  privaten `_WidgetXyz`). Stattdessen eigenständige, öffentliche, wiederverwendbare Widgets/Klassen
  in eigenen Dateien anlegen. (State-Klassen von `StatefulWidget` sind die übliche Ausnahme.)
- **Widgets wiederverwendbar gestalten.** Projektweit genutzte Widgets liegen unter
  `lib/core/general_widgets/` (je Widget eine Datei); feature-spezifische Widgets unter
  `lib/features/<feature>/presentation/widgets/` (je Widget eine Datei).
- **Vorhandene Widgets bevorzugen.** Vor dem Erstellen eines neuen Widgets immer prüfen, ob ein
  passendes bereits existiert, und dieses verwenden bzw. erweitern statt zu duplizieren.

Bestehende, wiederverwendbare Bausteine (vor Neubau zuerst hier suchen):
`GeneralTextField`, `GermanDateField`, `FormSection` (form), `CustomRectangularButton`,
`TemplateSelector` (buttons), `SidebarItem`/`AppSidebar`/`AppShellPage` (drawer), `PageRefreshScope`
— alle unter `lib/core/general_widgets/`.

## Current state / deferred work

Implemented: Zentralruf prefill, Zentralruf reply parsing + event-based mailbox monitoring (§4.3),
Word template filling with RVG calc + PDF preview, client register with filesystem Akten/Fälle (§4.6/§5),
form-template management, settings. The first-class **Vorgang/Auftrag** entity now exists (frontend
`vorgaenge` feature + backend `Vorgaenge` slice): it links Mandant ↔ Referenz ↔ reply ↔ document,
carries a lifecycle status (Angefragt → Beantwortet → Erstellt → Abgelegt → Versendet), and is what
"Vorgang abschließen" advances — closing counts up the Auftragsnummer and adds the Vorgang to the
register. All persistence moved into an embedded **SQLite** DB owned solely by the backend
(`AutomationDbContext`, `%APPDATA%\AutomationService\automation.db`); the former per-feature JSON
stores are gone, and the frontend reaches everything over HTTP. A `backup` feature backs up/restores
that DB (§8).

**Intelligent data reuse** (Punkte 1–7 des Verbesserungsplans, umgesetzt): wizard form data and the
Schadensaufstellung persist on the Vorgang (`feldWerte`/`schadensaufstellung`) and are offered as
prefill on re-entry, winning over the heuristics; explicitly bound fields flow back into Vorgang
fields (`VorgangRueckfluss`). `MandantErkennung` suggests matching register entries while typing
(Kennzeichen/surname, „Meinten Sie …?"-Banner) — suggestion only, takeover stays a click. The
backend `Versicherer` slice learns insurer contact data from every reply and fills `missingFields`
gaps with provenance hints. Reply→Vorgang matching falls back to Gegner-Kennzeichen + Unfalldatum
(`ZuordnungVermutet`, must be confirmed); conflicting reply values (Gegner, Unfalldatum) surface as
a keep/overwrite choice (`AntwortKonflikte` + dialog) instead of being silently dropped.
`VorgangVollstaendigkeit` shows missing data for the claim letter on the Vorgang tile, and prefilled
wizard fields show their source (`PrefillWert` provenance) per field.

Still not built (see REQUIREMENTS.md §4.7 / §6): **email sending** — "Vorgang abschließen" only marks
done, counts up, and registers; the actual send stays manual, and the recipient logic (§9) is not
wired yet. The **Sachgebiete/Auftrag register** exists as an in-app view in the exact column schema
(laufende Nr | Aktenzeichen Abteilung | Name ./. Gegner + Sachbestand v. Datum | Rechtsgebiet), but
the **Word export** into the firm's real multi-page register document is still deferred behind a
placeholder (`NichtVerfuegbarerRegisterWordExporter`, `verfuegbar == false`) until the real template
is available. Mailbox replies persist in the same DB (`DbReceivedReplyStore`, `ReceivedReplies`
table); each hit is best-effort linked to a Vorgang by Referenz (`VorgangId`/`Zugeordnet`, fallback
match flagged `ZuordnungVermutet`) without mutating the Vorgang — the takeover stays the confirmed
frontend step.
