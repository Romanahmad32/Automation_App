---
description: build_runner neu laufen lassen (DI, Routen, freezed, json)
---

Lass die Codegenerierung des Frontends neu laufen und pruefe das Ergebnis.

Aus `Automation_App_Frontend/`:

```
dart run build_runner build --delete-conflicting-outputs
```

Danach:

- `git status` zeigen. Getrackt sind nur `lib/core/di/injection.config.dart`
  und `lib/core/router/app_router.gr.dart` — aendert sich eine davon, gehoert
  die Aenderung in denselben Commit wie die Annotation, die sie ausgeloest hat.
- Generierte Dateien (`.g.dart`, `.freezed.dart`, `.gr.dart`,
  `injection.config.dart`) **nie** von Hand nachbearbeiten. Stimmt etwas nicht,
  liegt der Fehler in der Annotation oder in `build.yaml`.

Wann das noetig ist: nach jeder Aenderung an `@injectable`/`@Injectable`,
an den Routen in `lib/core/router/app_router.dart`, an freezed- oder
json_serializable-Klassen. Wird es vergessen, bleiben `flutter analyze` und
`flutter test` gruen, und die App bricht erst zur Laufzeit — genau deshalb
gehoert der Lauf zur Pruefkette (`/pruefen`).
