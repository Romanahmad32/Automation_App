part of 'register_import_cubit.dart';

/// Der Stand einer Registerübernahme: gewählte Datei, Bericht des Dienstes und
/// der Ausschnitt, den der Anwalt gerade ansieht.
///
/// Bewusst ein Zustand mit Merkmalen statt einer Kette von Zustandsklassen —
/// der Ablauf ist eine Bahn (wählen, prüfen, übernehmen), und der Bericht
/// bleibt am Ende stehen. Ein eigener „fertig"-Zustand müsste ihn erneut
/// mitführen.
class RegisterImportState extends Equatable {
  /// Pfad der gewählten Datei, für die Anzeige.
  final String? dateiPfad;

  /// Die gelesene Datei; nötig, weil das Übernehmen sie erneut schickt.
  final RegisterImportDatei? datei;

  /// Vorschau oder Ergebnis — derselbe Typ, siehe
  /// [RegisterImportBericht.angewendet].
  final RegisterImportBericht? bericht;

  final bool laufend;
  final String? fehler;

  /// Voreingestellt an: Gezeigt wird zuerst das, wozu ein Mensch etwas zu sagen
  /// hat.
  final bool nurZuPruefen;

  /// Die Jahrgänge, die schon geschrieben sind. Eine Datei darf mehrere
  /// enthalten, und jeder wird für sich abgeschlossen — deshalb reicht ein
  /// einzelnes „übernommen" am Bericht nicht aus.
  final Set<int> uebernommeneJahrgaenge;

  const RegisterImportState({
    this.dateiPfad,
    this.datei,
    this.bericht,
    this.laufend = false,
    this.fehler,
    this.nurZuPruefen = true,
    this.uebernommeneJahrgaenge = const {},
  });

  /// Alles geschrieben, was in der Datei stand.
  bool get uebernommen => bericht?.angewendet ?? false;

  /// „Alle übernehmen" ist erst möglich, wenn eine Vorschau vorliegt, sie
  /// etwas bewirkt und noch kein Jahrgang geschrieben wurde — ein zweiter Lauf
  /// über einen schon übernommenen Jahrgang wäre zwar harmlos, sähe aber wie
  /// eine zweite Übernahme aus.
  bool get kannUebernehmen =>
      !laufend &&
      !uebernommen &&
      datei != null &&
      uebernommeneJahrgaenge.isEmpty &&
      (bericht?.bewirktEtwas ?? false);

  bool kannJahrgangUebernehmen(int jahrgang) =>
      !laufend &&
      datei != null &&
      !uebernommeneJahrgaenge.contains(jahrgang) &&
      (befundZu(jahrgang)?.bewirktEtwas ?? false);

  /// Ob sich ein Jahrgang noch berichtigen lässt — anders als
  /// [kannJahrgangUebernehmen] **ohne** die Bedingung „bewirkt etwas": Ein
  /// Jahrgang, dessen Zeilen alle schon unverändert oder abgelehnt sind, lässt
  /// sich trotzdem bearbeiten, nur eigens übernehmen lässt er sich nicht.
  bool kannJahrgangBearbeiten(int jahrgang) =>
      !laufend && datei != null && !uebernommeneJahrgaenge.contains(jahrgang);

  bool istUebernommen(int jahrgang) =>
      uebernommeneJahrgaenge.contains(jahrgang);

  /// Wie viele Zeilen der Anwalt von Hand berichtigt hat.
  int get bearbeitetAnzahl =>
      datei?.jahrgaenge.fold<int>(
        0,
        (summe, jahr) =>
            summe + jahr.zeilen.where((zeile) => zeile.bearbeitet).length,
      ) ??
      0;

  RegisterImportJahrgang? jahrgangAus(int jahrgang) {
    for (final eintrag
        in datei?.jahrgaenge ?? const <RegisterImportJahrgang>[]) {
      if (eintrag.jahrgang == jahrgang) return eintrag;
    }
    return null;
  }

  JahrgangBefund? befundZu(int jahrgang) {
    for (final befund in bericht?.jahrgaenge ?? const <JahrgangBefund>[]) {
      if (befund.jahrgang == jahrgang) return befund;
    }
    return null;
  }

  /// Der Datensatz hinter einer Berichtszeile — das, was bearbeitet wird.
  /// Bericht und Datei stammen aus demselben Aufruf, die Zeilennummer trifft
  /// also; die Prüfung steht trotzdem hier, weil ein Fehlgriff sonst eine
  /// fremde Zeile änderte statt aufzufallen.
  RegisterImportZeile? zeileAus(int jahrgang, int zeile) {
    final eintrag = jahrgangAus(jahrgang);
    final stelle = zeile - 1;
    if (eintrag == null || stelle < 0 || stelle >= eintrag.zeilen.length) {
      return null;
    }
    return eintrag.zeilen[stelle];
  }

  /// Der Ausgangszustand für die nächste Datei.
  RegisterImportState zurueckgesetzt({
    String? dateiPfad,
    bool laufend = false,
  }) => RegisterImportState(
    dateiPfad: dateiPfad,
    laufend: laufend,
    nurZuPruefen: nurZuPruefen,
  );

  /// Nicht übergebene Felder bleiben stehen. [fehler] muss sich auch wieder
  /// leeren lassen — dafür der Schalter, weil `null` hier „unverändert" heißt.
  RegisterImportState copyWith({
    String? dateiPfad,
    RegisterImportDatei? datei,
    RegisterImportBericht? bericht,
    bool? laufend,
    String? fehler,
    bool? nurZuPruefen,
    Set<int>? uebernommeneJahrgaenge,
    bool fehlerLoeschen = false,
  }) => RegisterImportState(
    dateiPfad: dateiPfad ?? this.dateiPfad,
    datei: datei ?? this.datei,
    bericht: bericht ?? this.bericht,
    laufend: laufend ?? this.laufend,
    fehler: fehlerLoeschen ? null : fehler ?? this.fehler,
    nurZuPruefen: nurZuPruefen ?? this.nurZuPruefen,
    uebernommeneJahrgaenge:
        uebernommeneJahrgaenge ?? this.uebernommeneJahrgaenge,
  );

  @override
  List<Object?> get props => [
    dateiPfad,
    datei,
    bericht,
    laufend,
    fehler,
    nurZuPruefen,
    uebernommeneJahrgaenge,
  ];
}
