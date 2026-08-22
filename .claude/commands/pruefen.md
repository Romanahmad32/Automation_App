---
description: Komplette Pruefkette laufen lassen — dieselben Schritte wie die CI
---

Fuehre die Pruefkette dieses Repos aus:

```
./scripts/check.ps1
```

Das Skript faehrt dieselben Schritte wie `.github/workflows/ci.yml` — Pub get,
Codegenerierung, Abgleich des generierten Stands, Formatierung, Analyse und
Tests im Frontend, Build, Tests und Formatierung im Backend. Es bricht nicht
beim ersten Fehler ab, sondern fasst am Ende alles zusammen. Fuer einen
Teillauf: `-NurFrontend` bzw. `-NurBackend`.

Regeln fuer die Auswertung:

- Melde jeden Fehlschlag mit der echten Ausgabe, nicht zusammengefasst.
- Ein fehlschlagender Architektur-, Laengen- oder Vertragstest wird **nicht**
  dadurch geloest, dass die Regel gelockert oder eine Ausnahme eingetragen
  wird. Er sagt, dass der Code aufzuteilen bzw. der Vertrag nachzuziehen ist.
  Begruendete Ausnahmen kommen namentlich in den Test, nie als hochgesetztes
  Limit.
- Faellt `OpenApiVertragTests`, hat sich der HTTP-Vertrag geaendert: den Diff
  von `docs/openapi.json` ansehen. Ist die Aenderung gewollt, mitcommitten und
  pruefen, ob die Dart-Seite nachzieht; ist sie es nicht, ist sie soeben
  versehentlich im Backend entstanden.
- Laeuft ein Schritt nicht durch, weil eine Voraussetzung fehlt (Toolchain,
  fehlendes SDK), sag das ausdruecklich, statt den Schritt zu ueberspringen
  und die Kette als gruen zu melden.
