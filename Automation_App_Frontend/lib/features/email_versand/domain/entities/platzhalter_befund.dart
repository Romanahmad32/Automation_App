import 'package:equatable/equatable.dart';

/// Was ein `{{Platzhalter}}` einer Mail-Textvorlage ergeben hat (§4.7) — für
/// die Übersicht im Versanddialog.
///
/// Sie beantwortet die Frage, die ein fertig gefüllter Text nicht mehr
/// beantwortet: **Woher kommt das, und was ist leer geblieben?** Ohne sie
/// sieht ein falsch belegter Platzhalter aus wie ein Tippfehler im Text.
class PlatzhalterBefund extends Equatable {
  /// Der Name, wie er in der Vorlage steht — ohne die geschweiften Klammern.
  final String name;

  /// Was eingesetzt wurde; leer heißt: nichts, und die Zeile entfällt.
  final String wert;

  /// Woher der Wert stammt, im Klartext („aus dem Mandanten"). Leer, wenn es
  /// nichts einzusetzen gab.
  final String herkunft;

  const PlatzhalterBefund({
    required this.name,
    this.wert = '',
    this.herkunft = '',
  });

  bool get istLeer => wert.trim().isEmpty;

  /// Der Platzhalter so, wie er in der Vorlage steht — mit Klammern.
  String get geschrieben => '{{$name}}';

  @override
  List<Object?> get props => [name, wert, herkunft];
}
