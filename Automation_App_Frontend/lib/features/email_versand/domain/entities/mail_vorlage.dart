import 'package:equatable/equatable.dart';

/// Eine vom Anwalt gepflegte Mail-Textvorlage (§4.7, §5.3): Name, Betreff und
/// Nachrichtentext, beide mit `{{Platzhalter}}` in derselben Schreibweise wie
/// in den Word-Vorlagen.
///
/// Der Text endet **vor** der Signatur — die steht in den Einstellungen und
/// wird beim Versand angehängt. Eine Vorlage, die sie mitbrächte, ließe sie
/// unter jeder Mail doppelt erscheinen.
class MailVorlage extends Equatable {
  /// 0 für eine noch nicht gespeicherte Vorlage; die Nummer vergibt der
  /// Bestand im Backend.
  final int id;

  /// Wonach der Anwalt sie beim Verfassen auswählt — im Bestand eindeutig.
  final String name;

  final String betreff;
  final String text;

  const MailVorlage({
    this.id = 0,
    this.name = '',
    this.betreff = '',
    this.text = '',
  });

  bool get istGespeichert => id > 0;

  factory MailVorlage.fromJson(Map<String, dynamic> json) => MailVorlage(
    id: json['id'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    betreff: json['betreff'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );

  /// Zum Anlegen und Ändern; die `id` steht beim Ändern im Pfad und geht
  /// deshalb nicht mit.
  Map<String, dynamic> toJson() => {
    'name': name,
    'betreff': betreff,
    'text': text,
  };

  MailVorlage copyWith({String? name, String? betreff, String? text}) =>
      MailVorlage(
        id: id,
        name: name ?? this.name,
        betreff: betreff ?? this.betreff,
        text: text ?? this.text,
      );

  @override
  List<Object?> get props => [id, name, betreff, text];
}
