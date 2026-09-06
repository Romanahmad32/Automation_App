import 'package:equatable/equatable.dart';

/// Was an der Mail noch fehlt — je Feld, nicht als Liste (§4.7).
///
/// Vorher stand das als Kasten über dem Formular: „Zum Senden fehlt noch …".
/// Der Kasten war dauerhaft da, nahm oben im Dialog den Platz weg, den die
/// Empfängerzeilen brauchen, und stand dort auch, solange der Anwalt noch gar
/// nichts eingetippt hatte — ein Vorwurf für einen leeren Entwurf, der eben
/// erst geöffnet wurde.
///
/// Deshalb je Feld: Der Mangel steht **an** dem Feld, das ihn behebt — markiert
/// wird er erst, nachdem „Senden" einmal gedrückt wurde (`markiert` im
/// Zustand), sonst wäre jedes leere Feld ein Vorwurf an einen eben erst
/// geöffneten Entwurf.
///
/// **Der erste offene Punkt steht trotzdem von Anfang an da** (§4.7, ergänzt am
/// 06.09.2026): in der Statuszeile über den Knöpfen ([erster]). Was zum Senden
/// fehlt, nach dem Klick zu erfahren, war die eine Auskunft, die zu spät kam.
class VersandPruefung extends Equatable {
  /// Mangel an der Zeile „An".
  final String? anFehler;

  /// Mangel an der Zeile „Kopie (CC)" — nur eine nicht übernommene Eingabe.
  final String? kopieFehler;

  final String? betreffFehler;

  /// Mindestens ein Platzhalter aus Mandanten-, Vorgangs- oder
  /// Versichererdaten steht noch als `{{...}}` in Betreff oder Text und ginge
  /// wörtlich so hinaus (§4.7, ergänzt am 06.09.2026).
  ///
  /// Er hat **kein eigenes Feld**, an dem er stünde — die offenen Stellen
  /// zeigt die Platzhalter-Übersicht im Abschnitt „Inhalt". Deshalb steht der
  /// Satz in der Statuszeile über den Knöpfen, und zwar bevor jemand drückt.
  final String? platzhalterFehler;

  /// Die Nachricht ist schwerer, als das Postfach durchlässt.
  final String? groesseFehler;

  const VersandPruefung({
    this.anFehler,
    this.kopieFehler,
    this.betreffFehler,
    this.platzhalterFehler,
    this.groesseFehler,
  });

  /// Nichts offen — auch der Zustand, in dem das Formular nichts markiert.
  static const VersandPruefung ohneMangel = VersandPruefung();

  /// Die offenen Punkte in der Reihenfolge, in der sie im Formular stehen.
  List<String> get punkte => [
    ?anFehler,
    ?kopieFehler,
    ?betreffFehler,
    ?platzhalterFehler,
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
    platzhalterFehler,
    groesseFehler,
  ];
}
