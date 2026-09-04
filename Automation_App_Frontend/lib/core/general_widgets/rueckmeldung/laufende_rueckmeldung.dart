import 'dart:async';

import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_inhalt.dart';
import 'package:flutter/widgets.dart';

/// Eine Meldung, solange sie im Stapel steht: ihr Inhalt, **ihr eigener**
/// Timer und ein Schlüssel, der sie über Neuaufbauten hinweg identifiziert.
///
/// Warum je Meldung ein eigener Timer (04.09.2026, Issue #56): Der Stapel zeigt
/// mehrere Meldungen gleichzeitig. Ein gemeinsamer Timer würde die zuletzt
/// gezeigte Meldung mit der ältesten zusammen abräumen — oder die älteste
/// künstlich am Leben halten.
///
/// Warum ein [UniqueKey]: Kommt eine Meldung dazu, baut der Stapel neu auf.
/// Ohne stabilen Schlüssel ordnet Flutter die Zustände der Karten der Reihe
/// nach zu — die bereits stehende Karte übernähme den frischen Einblend-Zustand
/// und blitzte auf. Mit Schlüssel bleibt jede Karte bei ihrem Zustand.
class LaufendeRueckmeldung {
  LaufendeRueckmeldung(this.inhalt);

  /// Nicht mehr `final` (04.09.2026): Trifft `RueckmeldungsSteuerung.zeige`
  /// per `gleichWie` auf diese laufende Meldung, ersetzt sie den Inhalt durch
  /// den neuen, statt ihn zu verwerfen — sonst hinge an einer wiederholten
  /// Fehlermeldung noch die Aktion des ersten Versuchs, und „Erneut
  /// versuchen" griffe auf einen veralteten Schnappschuss zurück (§7.2).
  /// Schlüssel und Karten-Identität bleiben dabei unverändert, deshalb
  /// blitzt die Karte nicht auf.
  RueckmeldungsInhalt inhalt;

  /// Identität der Karte im Stapel.
  final Key schluessel = UniqueKey();

  /// Läuft ab, wenn die Meldung von selbst verschwinden soll; `null` bei
  /// Meldungen, die stehen bleiben (Fehler).
  Timer? timer;

  /// Bricht den Timer ab — beim Schließen, beim Verdrängen aus dem Stapel und
  /// beim Aufräumen, wenn der Baum unter der Meldung weggezogen wurde.
  void brichAb() {
    timer?.cancel();
    timer = null;
  }
}
