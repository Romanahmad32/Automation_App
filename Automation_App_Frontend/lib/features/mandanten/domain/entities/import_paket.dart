import 'package:equatable/equatable.dart';

/// Ein herausgegebenes Arbeitspaket, wie das Backend es führt
/// (`GET /api/ImportPakete`, Spiegel von `ImportPaketDto`).
///
/// Das Backend führt nur Buch: zusammengesetzt wird das Paket im Frontend, weil
/// nur dort der Bestand der Ordner bekannt ist (`FilesystemAktenDatasource`).
/// Gespeichert werden deshalb die Ordnernamen — und aus ihnen rechnet der
/// Dienst [erledigt] bei **jedem** Lesen neu aus. Es gibt damit keinen Stand,
/// der veralten kann: ein Ordner, dessen Zuordnung wieder gelöst wird, senkt
/// die Zahl von selbst.
///
/// Die Ordnernamen selbst kommen nicht mit — 200 Namen je Paket in einer
/// Übersicht mit vier Spalten wäre Verschwendung.
class ImportPaket extends Equatable {
  /// Fortlaufende Nummer ab 1, vom Backend vergeben.
  final int nummer;

  /// Wann das Paket herausgegeben wurde.
  final DateTime geholtAm;

  /// Ordner im Paket.
  final int anzahlOrdner;

  /// Wie viele davon inzwischen zugeordnet sind oder einen Vermerk tragen —
  /// dieselbe Rechnung wie „offen" im Zuordnungsstapel, nur andersherum.
  final int erledigt;

  /// Wann die zugehörige Importdatei eingelesen wurde. `null` = noch offen.
  final DateTime? eingelesenAm;

  /// Zeilen der eingelesenen Datei; `null`, solange das Paket offen ist.
  final int? zeilen;

  const ImportPaket({
    required this.nummer,
    required this.geholtAm,
    this.anzahlOrdner = 0,
    this.erledigt = 0,
    this.eingelesenAm,
    this.zeilen,
  });

  /// Noch nicht eingelesen. Ein teilweise abgearbeitetes Paket bleibt offen —
  /// das ist die ehrliche Antwort, und wie weit es ist, sagt [erledigt].
  bool get offen => eingelesenAm == null;

  /// Ordner des Pakets, die noch niemandem gehören. Nie negativ: [erledigt]
  /// zählt gegen einen Bestand, der sich zwischen zwei Abrufen verschieben
  /// kann, und eine negative Zahl wäre in der Anzeige nur verwirrend.
  int get offeneOrdner {
    final rest = anzahlOrdner - erledigt;
    return rest > 0 ? rest : 0;
  }

  factory ImportPaket.fromJson(Map<String, dynamic> json) => ImportPaket(
    nummer: json['nummer'] as int? ?? 0,
    geholtAm:
        DateTime.tryParse(json['geholtAm'] as String? ?? '') ?? DateTime.now(),
    anzahlOrdner: json['anzahlOrdner'] as int? ?? 0,
    erledigt: json['erledigt'] as int? ?? 0,
    eingelesenAm: DateTime.tryParse(json['eingelesenAm'] as String? ?? ''),
    zeilen: json['zeilen'] as int?,
  );

  @override
  List<Object?> get props => [
    nummer,
    geholtAm,
    anzahlOrdner,
    erledigt,
    eingelesenAm,
    zeilen,
  ];
}
