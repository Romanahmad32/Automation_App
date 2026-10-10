# test_driver — Einstieg für E2E-Abnahmetests per Marionette

`main_marionette.dart` startet die App wie `lib/main.dart`, aber mit dem `MarionetteBinding`.
Damit kann ein KI-Agent (Marionette MCP, `marionette_flutter` 0.7.0) die laufende Oberfläche
lesen und bedienen. Die Datei liegt absichtlich außerhalb von `lib/`, damit sie nie in einen
Release-Build gelangt.

## Starten

1. Dart MCP Server: `launch_app` mit `target=test_driver/main_marionette.dart` und
   `device=windows`.
2. Marionette: `connect` mit der `ws://`-Adresse des VM-Service aus der Ausgabe.

## Backend

Der Debug-Build startet den Dienst über die Umgebungsvariable `AUTOMATION_BACKEND_EXE`
(Pfad zur `AutomationService.exe`, siehe `lib/core/backend/backend_launcher.dart`). Läuft
auf Port 5143 schon ein Dienst, wird er übernommen.

## Selektoren

Marionette sucht Elemente bevorzugt über `key`, dann `identifier` (Semantics), zuletzt über
`text`. Koordinaten und `type` nur im Notfall.

## Sperre gegen Fehlklicks

Der Hook `.claude/hooks/marionette-sperre.ps1` sperrt Zentralruf-, Senden-, Versenden- und
Drucken-Knöpfe hart und lässt bei Entwurf, Postfach-Verbindung, Sicherung einspielen, Import,
Koordinaten-Tipps und Enter/Leertaste nachfragen. Einzelheiten in `.claude/README.md`.
