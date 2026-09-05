import 'package:equatable/equatable.dart';

/// Ein Arbeitspaket des Mandanten-Imports: die nächsten N offenen Aktenordner,
/// die ein Erzeuger (in der Praxis ein KI-Agent) in **einer** Sitzung bearbeitet.
///
/// Der Anlass ist die Größenordnung: rund 4040 Ordner in einem Durchgang zu
/// lesen sprengt jede Sitzung — der Erzeuger bricht ab oder wird gegen Ende
/// ungenau, ohne dass man es der Datei ansieht. Buch darüber führt die App und
/// nicht der Erzeuger: nur sie weiß über Sitzungsgrenzen hinweg, welche Ordner
/// schon zugeordnet oder vermerkt sind.
///
/// Das Backend wählt die Ordner aus (Zugeordnete und Vermerkte abgezogen,
/// stabil alphabetisch sortiert) und hält die Historie; hier steht nur, was
/// dabei herauskam.
class Arbeitspaket extends Equatable {
  /// Fortlaufende Nummer, ab 1 — sie steht im Dateinamen und ist das, wonach
  /// der Anwalt fragt („fehlt Paket 3?").
  final int nummer;

  /// Wann das Paket herausgegeben wurde.
  final DateTime geholtAm;

  /// Wann die Antwortdatei dazu eingelesen wurde; `null`, solange das nicht
  /// geschehen ist.
  final DateTime? eingelesenAm;

  /// Wie viele Ordner das Paket umfasst.
  final int ordnerAnzahl;

  /// Wie viele davon inzwischen zugeordnet oder vermerkt sind.
  final int erledigtAnzahl;

  /// Die Ordnernamen des Pakets, in der Reihenfolge des Dienstes.
  final List<String> ordnernamen;

  const Arbeitspaket({
    required this.nummer,
    required this.geholtAm,
    this.eingelesenAm,
    this.ordnerAnzahl = 0,
    this.erledigtAnzahl = 0,
    this.ordnernamen = const [],
  });

  /// Ob die Antwortdatei zu diesem Paket schon eingelesen wurde.
  bool get eingelesen => eingelesenAm != null;

  factory Arbeitspaket.fromJson(Map<String, dynamic> json) {
    final namen = json['ordnernamen'];
    return Arbeitspaket(
      nummer: json['nummer'] as int? ?? 0,
      geholtAm:
          DateTime.tryParse(json['geholtAm'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      eingelesenAm: DateTime.tryParse(json['eingelesenAm'] as String? ?? ''),
      ordnerAnzahl: json['ordnerAnzahl'] as int? ?? 0,
      erledigtAnzahl: json['erledigtAnzahl'] as int? ?? 0,
      ordnernamen: namen is List
          ? namen.whereType<String>().toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [
    nummer,
    geholtAm,
    eingelesenAm,
    ordnerAnzahl,
    erledigtAnzahl,
    ordnernamen,
  ];
}
