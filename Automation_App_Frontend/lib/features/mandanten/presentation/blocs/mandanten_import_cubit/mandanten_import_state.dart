part of 'mandanten_import_cubit.dart';

/// Der Stand eines Importvorgangs: gewählte Datei, Bericht des Dienstes und der
/// Ausschnitt, den der Anwalt gerade ansieht.
///
/// Bewusst ein Zustand mit Merkmalen statt einer Kette von Zustandsklassen —
/// der Ablauf ist eine Bahn (wählen, prüfen, übernehmen), und der Bericht
/// bleibt am Ende stehen. Ein eigener „fertig"-Zustand müsste ihn erneut
/// mitführen.
class MandantenImportState extends Equatable {
  /// Pfad der gewählten Datei, für die Anzeige.
  final String? dateiPfad;

  /// Die gelesene Datei; nötig, weil das Übernehmen sie erneut schickt.
  final MandantenImportDatei? datei;

  /// Vorschau oder Ergebnis — derselbe Typ, siehe [ImportBericht.angewendet].
  final ImportBericht? bericht;

  final bool laufend;
  final String? fehler;
  final ImportFilter filter;

  const MandantenImportState({
    this.dateiPfad,
    this.datei,
    this.bericht,
    this.laufend = false,
    this.fehler,
    this.filter = const ImportFilter(),
  });

  bool get uebernommen => bericht?.angewendet ?? false;

  /// Übernehmen ist erst möglich, wenn eine Vorschau vorliegt, sie etwas
  /// bewirkt und sie noch nicht geschrieben wurde.
  bool get kannUebernehmen =>
      !laufend &&
      !uebernommen &&
      datei != null &&
      (bericht?.bewirktEtwas ?? false);

  /// Wie viele Zeilen der Anwalt von Hand berichtigt hat.
  int get bearbeitetAnzahl =>
      datei?.mandanten.where((eintrag) => eintrag.bearbeitet).length ?? 0;

  /// Der Datensatz hinter einer Berichtszeile — das, was bearbeitet wird.
  /// Bericht und Datei stammen aus demselben Aufruf, die Zeilennummer trifft
  /// also; die Prüfung steht trotzdem hier, weil ein Fehlgriff sonst eine
  /// fremde Zeile änderte statt aufzufallen.
  ImportMandantEintrag? eintragAus(int zeile) {
    final mandanten = datei?.mandanten;
    if (mandanten == null || zeile < 0 || zeile >= mandanten.length) {
      return null;
    }
    return mandanten[zeile];
  }

  List<ImportEintrag> get sichtbar =>
      filter.anwenden(bericht?.eintraege ?? const []);

  Map<ImportSicht, int> get zaehler =>
      filter.zaehlen(bericht?.eintraege ?? const []);

  /// Nicht übergebene Felder bleiben stehen. [fehler] und [bericht] müssen sich
  /// auch wieder leeren lassen — dafür die beiden Schalter, weil `null` hier
  /// „unverändert" heißt.
  MandantenImportState copyWith({
    String? dateiPfad,
    MandantenImportDatei? datei,
    ImportBericht? bericht,
    bool? laufend,
    String? fehler,
    ImportFilter? filter,
    bool fehlerLoeschen = false,
    bool berichtLoeschen = false,
  }) => MandantenImportState(
    dateiPfad: dateiPfad ?? this.dateiPfad,
    datei: datei ?? this.datei,
    bericht: berichtLoeschen ? null : bericht ?? this.bericht,
    laufend: laufend ?? this.laufend,
    fehler: fehlerLoeschen ? null : fehler ?? this.fehler,
    filter: filter ?? this.filter,
  );

  @override
  List<Object?> get props => [
    dateiPfad,
    datei,
    bericht,
    laufend,
    fehler,
    filter,
  ];
}
