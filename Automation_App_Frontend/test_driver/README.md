# test_driver — Einstieg für E2E-Abnahmetests per Marionette

`main_marionette.dart` startet die App wie `lib/main.dart`, aber mit dem `MarionetteBinding`.
Damit kann ein KI-Agent (Marionette MCP, `marionette_flutter` 0.7.0) die laufende Oberfläche
lesen und bedienen. Die Datei liegt absichtlich außerhalb von `lib/`, damit sie nie in einen
Release-Build gelangt.

## Starten

**Abgeschottet (Testmodus, Issue #168):** `./scripts/e2e-start.ps1` aus dem Repo-Stamm. Es baut und startet
den Dienst in der Umgebung `E2E` (Port 5243, eigener Datenordner unter `%TEMP%\automation-e2e\<zeit>\daten`,
Attrappen für Zentralruf, Versand, Entwurf und Druck), legt einen Ausgangsbestand an und startet die App mit
diesem Einstieg. Die `ws://`-Adresse für Marionette `connect` steht danach in der Ausgabe und in
`<Wurzel>\vmservice.txt`. `./scripts/e2e-start.ps1 -Beenden` räumt auf. Alles Weitere in `docs/RELEASE.md`
(Abschnitt „E2E-Testmodus"). Dieselbe Umgebung nutzt die E2E-Suite unter `integration_test/` (#184), gestartet
über `scripts/e2e-suite.ps1`; sie hat einen eigenen Einstieg je Durchlauf und braucht diesen hier nicht.

**Von Hand (echter Bestand — nur, wenn du weißt, was du tust):**

1. Dart MCP Server: `launch_app` mit `target=test_driver/main_marionette.dart` und
   `device=windows`.
2. Marionette: `connect` mit der `ws://`-Adresse des VM-Service aus der Ausgabe.

## Backend

Zwei Dart-Defines schalten die App auf den Testmodus um (beide setzt `e2e-start.ps1`):

- `AUTOMATION_BACKEND_PORT` (Vorgabe 5143) — Port des Dienstes, im Testmodus 5243.
- `AUTOMATION_TESTMODUS=true` — der `BackendLauncher` übernimmt nur einen Dienst, dessen `/health` `testmodus`
  meldet, und startet sonst keinen. Läuft also die installierte App auf 5143, hängt sich der Testlauf nie an
  deren Datenbank; stattdessen erscheint der Startfehler-Bildschirm mit dem Hinweis auf das Skript.

Ohne diese Defines startet der Debug-Build den Dienst über die Umgebungsvariable `AUTOMATION_BACKEND_EXE`
(Pfad zur `AutomationService.exe`, siehe `lib/core/backend/backend_launcher.dart`). Läuft auf Port 5143
schon ein Dienst, wird er übernommen.

Was der Testmodus-Dienst hinterlässt, liegt unter `<Datenordner>\Testmodus\`: `protokoll.jsonl` (je Aktion eine
Zeile mit `zeit`, `aktion`, `referenz`, `datei`; `aktion` ist `zentralruf-anfrage`, `versand`, `gesendet-ablage`,
`entwurf` oder `druck`), `Versand\`, `Entwuerfe\` und `Druck\`. Prüfungen stützen sich auf `protokoll.jsonl` →
`datei`, nicht auf das Namensmuster. Beim Entwurf zeigt die App „Outlook war nicht erreichbar …" — im Testmodus
erwartet. „In Word öffnen" und die PDF-Vorschau laufen echt (Word), ohne Außenwirkung.

## Selektoren

Marionette sucht Elemente bevorzugt über `key`, dann `identifier` (Semantics), zuletzt über
`text`. Koordinaten und `type` nur im Notfall.

`text` vergleicht **exakt** und liest von Haus aus nur `Text`/`RichText`/Eingabefelder. Damit
auch die eingeklappte Seitenleiste und die Symbolknöpfe erreichbar sind, liefert
`beschriftungFuerMarionette` in `marionette_konfiguration.dart` für ein `SidebarItem` sein `label` und
für einen `IconButton` seinen `tooltip`: `tap` mit `text: "Mandanten"` wechselt den Reiter,
`text: "Löschen"` trifft den Mülleimer. Gleichnamige Knöpfe einer Liste trennt
`ancestor_keys`, etwa `["7/26 C03_123 ABC"]` — die Vorgangskachel trägt `ValueKey(referenz)`.

Die Konfiguration steht in `marionette_konfiguration.dart`: marionette_flutter kennt nur die Material-Typen des SDK, deshalb meldet `istBedienelement` die `material_ui`-Typen als interaktiv und `beschriftungFuerMarionette` reicht Label und Tooltip nach.

**Schlüssel (`key`).** Namensschema `<bereich>-<element>[-<id>]` in kebab-case; die Werte stehen als
`static const Key …Schluessel` bzw. `static Key schluessel(…)` am jeweiligen Widget. Eine Vorgangskachel trägt
weiter `ValueKey(referenz)`.

| Element | `key` |
|---|---|
| jedes Formularfeld (`formControlName`) | `feld-<formControlName>`, z. B. `feld-mandantVorname` |
| Suchfelder | `akte-zuordnen-suche`, `mandanten-suche`, `zuordnen-suche`, `vorlagen-suche` |
| Vorlagenwahl im Assistenten | `vorlage-auswahl` |
| Vorgangsauswahl Word / Eintrag | `vorgang-auswahl` / `vorgang-auswahl-<referenz>` (`…-keiner`) |
| Vorgangsauswahl Versand / Eintrag | `versand-vorgang` / `versand-vorgang-<referenz>` |
| Vorgangszuordnung Antwort / Eintrag | `zuordnung-vorgang` / `zuordnung-vorgang-<referenz>` |
| Mandant übernehmen (Vorgang starten) / Eintrag | `mandant-auswahl` / `mandant-auswahl-<id>` (`…-neu`) |
| Antwort manuell einfügen: Mailtext | `antwort-manuell-text` |
| Mandantenkarte, Formularvorlagen-Zeile | `mandant-<id>`, `vorlage-<id>` |
| Vollmacht-Art | `vollmacht-art-unfallsachen`, `…-bussgeldsachen`, `…-strafsache` |
| Versand Betreff / Text | `versand-betreff` / `versand-text` |
| Versand Empfänger-Eingabe | `versand-an` / `versand-kopie` |
| gesperrt (Hook schlägt an) | `zentralruf-formular-ausfuellen`, `versand-senden`, `vollmacht-drucken` |

Eigene Tippflächen (`InkWell`) tragen `Semantics(button: true)` und sind damit auch über `text` bzw. `identifier`
auffindbar. Gleichnamige Knöpfe einer Liste trennt `ancestor_keys` mit dem Schlüssel des Listeneintrags, etwa
`["mandant-3"]`. Ein neuer Schlüssel darf die Sperre (siehe unten) nicht zufällig treffen, ein gefährlicher
soll sie treffen: `.claude/hooks/marionette-sperre.ps1` ist die Probe.

`stop_app` beendet nur `flutter run`; das App-Fenster bleibt offen und muss danach geschlossen
werden (der Dienst beendet sich dann selbst).

## Sperre gegen Fehlklicks

Der Hook `.claude/hooks/marionette-sperre.ps1` sperrt Zentralruf-, Senden-, Versenden- und
Drucken-Knöpfe hart und lässt bei Entwurf, Postfach-Verbindung, Sicherung einspielen, Import,
Koordinaten-Tipps und Enter/Leertaste nachfragen. Einzelheiten in `.claude/README.md`. Sie bleibt auch im Testmodus hart: Zentralruf, Senden und Drucken
prüft die integration_test-Suite (#184), nicht der Agent.
