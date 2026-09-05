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

  /// Der gescannte Ordnerbestand und das Register — das, woran die Datei
  /// gemessen wird. Überlebt „Andere Datei": der Scan gehört zur Maschine,
  /// nicht zur Datei.
  final ImportUmfeld umfeld;

  /// Was die Oberfläche aus [umfeld] und dem Bericht abgeleitet hat.
  final ImportBefund befund;

  const MandantenImportState({
    this.dateiPfad,
    this.datei,
    this.bericht,
    this.laufend = false,
    this.fehler,
    this.filter = const ImportFilter(),
    this.umfeld = const ImportUmfeld(),
    this.befund = const ImportBefund(),
  });

  bool get uebernommen => bericht?.angewendet ?? false;

  /// Übernehmen ist erst möglich, wenn eine Vorschau vorliegt, sie etwas
  /// bewirkt, sie noch nicht geschrieben wurde — und keine Ordnerangabe darin
  /// ins Leere zeigt (siehe [ImportBefund.sperrtUebernahme]).
  bool get kannUebernehmen =>
      !laufend &&
      !uebernommen &&
      datei != null &&
      !befund.sperrtUebernahme &&
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

  List<ImportEintrag> get sichtbar => filter.anwenden(
    bericht?.eintraege ?? const [],
    unbekannteZeilen: befund.unbekannteZeilen,
  );

  Map<ImportSicht, int> get zaehler => filter.zaehlen(
    bericht?.eintraege ?? const [],
    unbekannteZeilen: befund.unbekannteZeilen,
  );

  /// Der Ausgangszustand für die nächste Datei — [umfeld] bleibt stehen.
  ///
  /// „Andere Datei" wirft die Datei weg, nicht den Akten-Scan über viertausend
  /// Ordner: der beschreibt die Maschine und ändert sich davon nicht.
  MandantenImportState zurueckgesetzt({
    String? dateiPfad,
    bool laufend = false,
  }) => MandantenImportState(
    dateiPfad: dateiPfad,
    laufend: laufend,
    umfeld: umfeld,
  );

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
    ImportUmfeld? umfeld,
    ImportBefund? befund,
    bool fehlerLoeschen = false,
    bool berichtLoeschen = false,
  }) => MandantenImportState(
    dateiPfad: dateiPfad ?? this.dateiPfad,
    datei: datei ?? this.datei,
    bericht: berichtLoeschen ? null : bericht ?? this.bericht,
    laufend: laufend ?? this.laufend,
    fehler: fehlerLoeschen ? null : fehler ?? this.fehler,
    filter: filter ?? this.filter,
    umfeld: umfeld ?? this.umfeld,
    befund: befund ?? this.befund,
  );

  @override
  List<Object?> get props => [
    dateiPfad,
    datei,
    bericht,
    laufend,
    fehler,
    filter,
    umfeld,
    befund,
  ];
}
