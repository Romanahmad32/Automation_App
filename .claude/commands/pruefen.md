---
description: Komplette Pruefkette laufen lassen — dieselben Schritte wie die CI
---

Fuehre die Pruefkette dieses Repos aus, in dieser Reihenfolge. Es sind dieselben
Schritte, die `.github/workflows/ci.yml` faehrt — was hier gruen ist, ist auch
in der CI gruen.

**Frontend** (aus `Automation_App_Frontend/`):

1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs`
   — danach `git status` pruefen: aendert sich `injection.config.dart` oder
   `app_router.gr.dart`, war der generierte Stand veraltet. Die Aenderung
   gehoert mit in den Commit.
3. `dart format --output=none --set-exit-if-changed lib test`
4. `flutter analyze`
5. `flutter test` — enthaelt die Architektur-Tests unter `test/architecture/`
   (Schichtenregeln, Dateilaengen-Limit).

**Backend** (aus `AutomationService/AutomationService/`):

6. `dotnet build AutomationService.Tests --configuration Release`
   — `TreatWarningsAsErrors` ist an: jede neue Warnung bricht hier ab.
7. `dotnet test AutomationService.Tests --configuration Release --no-build`
   — enthaelt die Architektur-Tests unter `AutomationService.Tests/Architecture/`
   (Slice-Isolation, Namespace-Konvention, Dateilaenge).
8. `dotnet format ../AutomationService.slnx --verify-no-changes`

Regeln fuer die Auswertung:

- Melde jeden Fehlschlag mit der echten Ausgabe, nicht zusammengefasst.
- Ein fehlschlagender Architektur- oder Laengen-Test wird **nicht** dadurch
  geloest, dass die Regel gelockert oder eine Ausnahme eingetragen wird. Er
  sagt, dass der Code aufzuteilen ist. Ausnahmen kommen namentlich und mit
  Begruendung in den Test, nie als hochgesetztes Limit.
- Laeuft ein Schritt nicht durch, weil eine Voraussetzung fehlt (Toolchain,
  Backend nicht gestartet), sag das ausdruecklich, statt den Schritt zu
  ueberspringen und die Kette als gruen zu melden.
