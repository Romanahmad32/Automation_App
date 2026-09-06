import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/usecases/importiere_mandanten.dart';
import 'package:automation_app/features/mandanten/domain/usecases/lies_import_datei.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/import_befund.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/import_umfeld.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_filter.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
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
  final UseCase<List<Akte>, NoParams> _getAkten;
  final UseCase<List<Mandant>, NoParams> _getMandanten;

  MandantenImportCubit(
    this._liesDatei,
    this._importiere,
    this._getAkten,
    this._getMandanten,
  ) : super(const MandantenImportState());

  /// Holt einmal, woran die Datei gemessen wird: den Akten-Scan und das
  /// Register. Läuft neben dem Aufbau der Seite und hält nichts auf — die
  /// Dateiauswahl ist ohne beides bedienbar.
  ///
  /// Scheitert eines von beiden, bleibt es leer und wird **nicht** gemeldet.
  /// Das ist kein Fehlerschlucken, sondern die Rangfolge: Der Import ist die
  /// Hauptsache. Ohne Scan wird keine Ordnerangabe beanstandet
  /// (`OrdnerPruefung`), ohne Register gibt es keinen Ähnlichkeitshinweis —
  /// eine rote Meldung darüber hielte den Anwalt von einer Arbeit ab, die er
  /// sehr wohl tun kann.
  Future<void> umfeldLaden() async {
    final akten = await _getAkten(const NoParams());
    final register = await _getMandanten(const NoParams());
    if (isClosed) return;

    final umfeld = ImportUmfeld(
      ordnernamen: switch (akten) {
        Right(value: final gefunden) => [
          for (final akte in gefunden) akte.ordnername,
        ],
        Left() => const [],
      },
      mandanten: switch (register) {
        Right(value: final gefunden) => gefunden,
        Left() => const [],
      },
    );
    emit(state.copyWith(umfeld: umfeld, befund: _befundZu(umfeld)));
  }

  /// Nimmt eine im Arbeitsspeicher zusammengestellte Datei an, als wäre sie
  /// gewählt worden, und fährt dieselbe Vorschau. [herkunft] steht dann
  /// anstelle eines Dateipfads über der Liste.
  ///
  /// Ausdrücklich **kein** zweiter Weg ins Register: Vorschau vor dem
  /// Schreiben, „Ergänzen nie überschreiben", eine Transaktion und die
  /// Paket-Buchführung gelten damit unverändert. Wer hier abkürzte, hätte eine
  /// zweite Zuordnungslogik, die beim ersten Sonderfall auseinanderliefe.
  Future<void> uebernimmDatei(
    MandantenImportDatei datei, {
    String herkunft = '',
  }) async {
    emit(state.zurueckgesetzt(dateiPfad: herkunft, laufend: true));
    await _pruefeOderSchreibe(datei, uebernehmen: false);
  }

  /// Liest die gewählte Datei und holt sofort die Vorschau dazu.
  Future<void> dateiWaehlen(String pfad) async {
    emit(state.zurueckgesetzt(dateiPfad: pfad, laufend: true));

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

  /// Zurück auf Anfang — für die nächste Datei. Der Akten-Scan bleibt stehen.
  void zuruecksetzen() => emit(state.zurueckgesetzt());

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
    if (isClosed) return;

    switch (ergebnis) {
      case Left(value: final failure):
        emit(state.copyWith(laufend: false, fehler: failure.message));
      case Right(value: final bericht):
        emit(
          state.copyWith(
            datei: datei,
            bericht: bericht,
            laufend: false,
            fehlerLoeschen: true,
            befund: ImportBefund.zu(
              umfeld: state.umfeld,
              datei: datei,
              bericht: bericht,
            ),
          ),
        );
    }
  }

  /// Die Befunde zum Stand, den der Zustand gerade hält — für den Fall, dass
  /// das Umfeld erst eintrifft, während schon eine Vorschau steht. Ohne Datei
  /// oder Bericht gibt es nichts zu rechnen.
  ImportBefund _befundZu(ImportUmfeld umfeld) {
    final datei = state.datei;
    final bericht = state.bericht;
    if (datei == null || bericht == null) return const ImportBefund();
    return ImportBefund.zu(umfeld: umfeld, datei: datei, bericht: bericht);
  }
}
