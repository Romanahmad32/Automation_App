import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_aktion.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_art.dart';
import 'package:flutter/material.dart';

/// Alles, was eine einzelne Rückmeldung ausmacht: Text, Art, optionale Aktion
/// und eine überschriebene Anzeigedauer.
///
/// Warum ein eigener Wert statt vier Parameter durch drei Schichten zu reichen:
/// `RueckmeldungsSteuerung` muss zwei Fragen beantworten — „ist das dieselbe
/// Meldung wie die sichtbare?" (`gleichWie`) und „wie lange bleibt sie stehen?"
/// (`anzeigedauer`). Beide gehören an die Daten, nicht in die Steuerung.
@immutable
class RueckmeldungsInhalt {
  const RueckmeldungsInhalt({
    required this.text,
    required this.art,
    this.aktion,
    this.dauer,
  });

  /// Der fertige Satz für den Anwalt, nicht die technische Ursache.
  final String text;

  final RueckmeldungsArt art;

  final RueckmeldungsAktion? aktion;

  /// Überschreibt die Standarddauer der Art; `null` heißt „nimm die der Art".
  final Duration? dauer;

  /// Wie lange die Meldung tatsächlich stehen bleibt — `null` heißt: bis der
  /// Anwalt sie schließt.
  ///
  /// Mit Aktion gilt eine Untergrenze, sonst verschwände der Knopf, bevor er
  /// getroffen ist. Eine Art ohne Standarddauer (Fehler) bleibt auch mit Aktion
  /// stehen: „bleibt" ist die längere Zusage, nicht die kürzere.
  Duration? get anzeigedauer {
    final gewuenscht = dauer ?? art.standardDauer;
    if (gewuenscht == null) return null;
    if (aktion == null) return gewuenscht;
    return gewuenscht < RueckmeldungsArt.mitAktionMindestens
        ? RueckmeldungsArt.mitAktionMindestens
        : gewuenscht;
  }

  /// Dieselbe Meldung wie [andere]? Verglichen werden Text und Art — nicht die
  /// Aktion und nicht die Dauer.
  ///
  /// Damit ist entschieden, was bei einer Wiederholung passiert: Ein Bloc, der
  /// denselben Fehlerzustand zweimal ausliefert (jeder Rebuild einer
  /// Listener-Kette tut das), lässt die stehende Karte in Ruhe und startet nur
  /// ihren Timer neu, statt sie neu einzublenden — das Flackern hat man sonst
  /// als „Snackbar-Wiederholung" von Hand wegprogrammiert.
  bool gleichWie(RueckmeldungsInhalt andere) =>
      text == andere.text && art == andere.art;
}
