import 'package:equatable/equatable.dart';

/// Ein persönlicher Zusatzgruß als **Textbaustein** (§4.7, §7.1) — einer der
/// Grüße, aus denen der Anwalt beim Verfassen wählt.
///
/// Bewusst eine Liste von Bausteinen und **kein Merkmal von Personen**: Sie
/// hängt an keinem Mandanten und ordnet niemanden ein. Was am Mandanten steht
/// ([Mandant.persoenlicheGrussformel]), ist freier Text und nur die
/// Vorbelegung.
class Grussformel extends Equatable {
  /// 0 für einen noch nicht gespeicherten Gruß; die Nummer vergibt der Bestand.
  final int id;

  /// Der Gruß, wie er in der Mail steht — im Bestand eindeutig.
  final String text;

  /// Reihenfolge in der Auswahl; 0 heißt „ans Ende".
  final int sortierung;

  const Grussformel({this.id = 0, this.text = '', this.sortierung = 0});

  bool get istGespeichert => id > 0;

  factory Grussformel.fromJson(Map<String, dynamic> json) => Grussformel(
    id: json['id'] as int? ?? 0,
    text: json['text'] as String? ?? '',
    sortierung: json['sortierung'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {'text': text, 'sortierung': sortierung};

  Grussformel copyWith({String? text, int? sortierung}) => Grussformel(
    id: id,
    text: text ?? this.text,
    sortierung: sortierung ?? this.sortierung,
  );

  @override
  List<Object?> get props => [id, text, sortierung];
}
