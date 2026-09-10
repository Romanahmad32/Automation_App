---
name: generieren
description: >-
  Flutter-build_runner für DI, auto_route, freezed oder json_serializable ausführen und den
  generierten Stand prüfen. Verwenden nach entsprechenden Annotationen oder bei der Aufforderung
  „generieren“ bzw. „build_runner“.
---

# Flutter-Code generieren

Lies den Befehlsabschnitt von `Automation_App_Frontend/CLAUDE.md` (dort steht der Aufruf, welche
generierten Dateien versioniert sind und dass generierte Dateien nie von Hand geändert werden) und
führe `dart run build_runner build` mit dem gepinnten Flutter-/Dart-SDK aus, sofern es lokal
verfügbar ist.

Arbeite aus `Automation_App_Frontend/`. Bearbeite generierte Dateien nie von Hand. Prüfe danach
mit `git status --short` und einem gezielten Diff ausschließlich, ob die erwarteten versionierten
Dateien geändert wurden; vorhandene Nutzeränderungen nicht zurücksetzen.
