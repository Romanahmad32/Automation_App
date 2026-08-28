import 'package:equatable/equatable.dart';

/// Was an der Mail noch fehlt — je Feld, nicht als Liste (§4.7).
///
/// Vorher stand das als Kasten über dem Formular: „Zum Senden fehlt noch …".
/// Der Kasten war dauerhaft da, nahm oben im Dialog den Platz weg, den die
/// Empfängerzeilen brauchen, und stand dort auch, solange der Anwalt noch gar
/// nichts eingetippt hatte — ein Vorwurf für einen leeren Entwurf, der eben
/// erst geöffnet wurde.
///
/// Deshalb je Feld: Der Mangel steht **an** dem Feld, das ihn behebt, und erst
/// nachdem „Senden" einmal gedrückt wurde. Vorher ist er null und kostet nichts.
class VersandPruefung extends Equatable {
  /// Mangel an der Zeile „An".
  final String? anFehler;

  /// Mangel an der Zeile „Kopie (CC)" — nur eine nicht übernommene Eingabe.
  final String? kopieFehler;

  final String? betreffFehler;

  /// Die Nachricht ist schwerer, als das Postfach durchlässt.
  final String? groesseFehler;

  const VersandPruefung({
    this.anFehler,
    this.kopieFehler,
    this.betreffFehler,
    this.groesseFehler,
  });

  /// Nichts offen — auch der Zustand, in dem das Formular nichts markiert.
  static const VersandPruefung ohneMangel = VersandPruefung();

  /// Die offenen Punkte in der Reihenfolge, in der sie im Formular stehen.
  List<String> get punkte => [
    ?anFehler,
    ?kopieFehler,
    ?betreffFehler,
    ?groesseFehler,
  ];

  bool get vollstaendig => punkte.isEmpty;

  /// Der erste offene Punkt, für die kurze Meldung neben dem Knopf. Wer drei
  /// Sätze gleichzeitig vorgesetzt bekommt, liest keinen davon; die übrigen
  /// stehen ohnehin an ihrem Feld.
  String? get erster => punkte.isEmpty ? null : punkte.first;

  @override
  List<Object?> get props => [
    anFehler,
    kopieFehler,
    betreffFehler,
    groesseFehler,
  ];
}
