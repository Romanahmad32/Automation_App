import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/usecases/importiere_mandanten.dart';
import 'package:automation_app/features/mandanten/domain/usecases/lies_import_datei.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_filter.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

part 'mandanten_import_state.dart';

/// Führt durch den Import: Datei einlesen, prüfen lassen, ansehen, ändern,
/// übernehmen.
///
/// Der Haltepunkt in der Mitte ist der Zweck der ganzen Übung. Eine maschinell
/// erzeugte Zuordnung über viertausend Ordner ungesehen ins Register zu
/// schreiben wäre kein Fortschritt gegenüber der Handarbeit, sondern nur ein
/// schnellerer Weg zu Fehlern, die hinterher niemand mehr findet. Deshalb
/// schreibt erst [uebernehmen] — und erst, nachdem derselbe Aufruf einmal ohne
/// Schreiben gelaufen ist und sein Ergebnis auf dem Bildschirm stand.
///
/// Aus demselben Grund ist die Vorschau nicht nur zum Ansehen: [eintragErsetzen]
/// und [eintragVerwerfen] ändern die Datei im Arbeitsspeicher. Wer eine falsch
/// gelesene Zeile sieht, soll sie richtigstellen können, statt die ganze Datei
/// verwerfen oder den Fehler mit übernehmen zu müssen. Die Datei auf der Platte
/// bleibt dabei unangetastet — „Andere Datei" holt jederzeit den Urzustand.
@injectable
class MandantenImportCubit extends Cubit<MandantenImportState> {
  final UseCase<MandantenImportDatei, LiesImportDateiParams> _liesDatei;
  final UseCase<ImportBericht, ImportiereMandantenParams> _importiere;
  final UseCase<List<Mandant>, NoParams> _getMandanten;

  MandantenImportCubit(this._liesDatei, this._importiere, this._getMandanten)
    : super(const MandantenImportState());

  /// Liest die gewählte Datei und holt sofort die Vorschau dazu.
  Future<void> dateiWaehlen(String pfad) async {
    emit(MandantenImportState(dateiPfad: pfad, laufend: true));

    // Das Register einmal je Datei holen: Es trägt den Ähnlichkeitsvergleich
    // und die Übernahme im Dialog. Scheitert der Abruf, läuft der Import
    // trotzdem weiter — dann fehlt der Hinweis, was allemal besser ist als
    // gar keine Vorschau.
    final register = await _getMandanten(const NoParams());
    if (register case Right(value: final mandanten)) {
      emit(state.copyWith(mandanten: mandanten));
    }

    final gelesen = await _liesDatei(LiesImportDateiParams(pfad: pfad));
    switch (gelesen) {
      case Left(value: final failure):
        emit(state.copyWith(laufend: false, fehler: failure.message));
      case Right(value: final datei):
        await _pruefeOderSchreibe(datei, uebernehmen: false);
    }
  }

  /// Ersetzt eine Zeile durch die von Hand berichtigte Fassung und lässt neu
  /// prüfen. Was die Änderung bewirkt, sagt wieder der Dienst — hier wird nicht
  /// nachgerechnet, sonst gäbe es zwei Auslegungen derselben Regeln.
  Future<void> eintragErsetzen(int zeile, ImportMandantEintrag geaendert) {
    return _mitGeaenderterDatei(zeile, (mandanten) {
      mandanten[zeile] = geaendert.alsBearbeitet();
    });
  }

  /// Nimmt eine Zeile aus dem Vorgang — für einen Eintrag, den der Erzeuger
  /// erfunden hat. Die Datei auf der Platte bleibt, wie sie ist.
  Future<void> eintragVerwerfen(int zeile) {
    return _mitGeaenderterDatei(
      zeile,
      (mandanten) => mandanten.removeAt(zeile),
    );
  }

  /// Schreibt, was die Vorschau gezeigt hat.
  Future<void> uebernehmen() async {
    final datei = state.datei;
    if (datei == null || state.laufend || state.uebernommen) return;
    emit(state.copyWith(laufend: true, fehlerLoeschen: true));
    await _pruefeOderSchreibe(datei, uebernehmen: true);
  }

  void filtern(ImportFilter filter) => emit(state.copyWith(filter: filter));

  /// Zurück auf Anfang — für die nächste Datei.
  void zuruecksetzen() => emit(const MandantenImportState());

  Future<void> _mitGeaenderterDatei(
    int zeile,
    void Function(List<ImportMandantEintrag>) aendere,
  ) async {
    final datei = state.datei;
    if (datei == null || state.laufend || state.uebernommen) return;
    if (zeile < 0 || zeile >= datei.mandanten.length) return;

    final mandanten = [...datei.mandanten];
    aendere(mandanten);

    emit(state.copyWith(laufend: true, fehlerLoeschen: true));
    await _pruefeOderSchreibe(
      MandantenImportDatei(
        version: datei.version,
        mandanten: mandanten,
        ohneMandantenbezug: datei.ohneMandantenbezug,
      ),
      uebernehmen: false,
    );
  }

  /// Die geänderte Datei wird erst zum Zustand, wenn ihr Bericht da ist. Sonst
  /// zeigte die Liste einen Augenblick lang Zeilennummern aus dem alten Bericht
  /// über den Einträgen der neuen Datei — und ein Klick träfe die falsche Zeile.
  Future<void> _pruefeOderSchreibe(
    MandantenImportDatei datei, {
    required bool uebernehmen,
  }) async {
    final ergebnis = await _importiere(
      ImportiereMandantenParams(datei: datei, uebernehmen: uebernehmen),
    );

    switch (ergebnis) {
      case Left(value: final failure):
        emit(state.copyWith(laufend: false, fehler: failure.message));
      case Right(value: final bericht):
        emit(
          state.copyWith(
            datei: datei,
            bericht: bericht,
            aehnliche: await _aehnlichkeiten(datei, bericht),
            laufend: false,
            fehlerLoeschen: true,
          ),
        );
    }
  }

  /// Die Ähnlichkeitstreffer zu den Zeilen, die der Dienst als `neu` einstuft
  /// — „Schmitt" bei vorhandenem „Schmidt". Nach **jedem** Bericht neu
  /// gerechnet: Ein berichtigter Name soll seinen Hinweis auch wieder
  /// verlieren.
  ///
  /// Nur `neu` zählt: Bei `ergaenzt` und `unveraendert` hat der Import den
  /// Mandanten ja schon getroffen, da wäre der Hinweis nur Lärm.
  ///
  /// Gerechnet wird in einem **eigenen Isolate** (`compute`). Der Vergleich
  /// läuft je Zeile über den ganzen Bestand und rechnet Levenshtein; bei einer
  /// Datei über den ganzen Aktenbestand sind das viertausend Zeilen mal
  /// mehrere tausend Registereinträge. Im Oberflächen-Isolat gerechnet stünde
  /// die App dabei still — ein Fehler, der in der Kanzlei auffällt und nicht
  /// in der Prüfkette.
  Future<Map<int, List<MandantVorschlag>>> _aehnlichkeiten(
    MandantenImportDatei datei,
    ImportBericht bericht,
  ) async {
    if (state.mandanten.isEmpty) return const {};

    final zeilen = <AehnlichkeitsZeile>[
      for (final eintrag in bericht.eintraege)
        if (eintrag.art == ImportArt.neu &&
            eintrag.zeile >= 0 &&
            eintrag.zeile < datei.mandanten.length)
          AehnlichkeitsZeile(
            zeile: eintrag.zeile,
            vorname: datei.mandanten[eintrag.zeile].vorname,
            nachname: datei.mandanten[eintrag.zeile].nachname,
          ),
    ];
    // Ohne Zeilen kein Isolate: Ein Isolat zu starten, um eine leere Karte
    // zurückzubekommen, kostet mehr als die Rechnung selbst.
    if (zeilen.isEmpty) return const {};

    return compute(
      MandantErkennung.findeZuZeilen,
      AehnlichkeitsAuftrag(mandanten: state.mandanten, zeilen: zeilen),
    );
  }
}
