import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_zeile.dart';
import 'package:automation_app/features/register_import/domain/usecases/importiere_register.dart';
import 'package:automation_app/features/register_import/domain/usecases/lies_register_import_datei.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'register_import_state.dart';

/// Führt durch die Übernahme der Registerhistorie: Datei einlesen, je Jahrgang
/// prüfen lassen, ansehen, berichtigen, übernehmen (§6.2).
///
/// Der Haltepunkt in der Mitte ist der Zweck der Übung. Das Word-Register hat
/// rund neunzig Seiten; einen maschinell erzeugten Auszug davon ungesehen in
/// die Datenbank zu schreiben wäre kein Fortschritt gegenüber dem Abtippen,
/// sondern nur ein schnellerer Weg zu Fehlern, die hinterher niemand mehr
/// findet. Deshalb schreibt erst [uebernehmen] — und erst, nachdem derselbe
/// Aufruf einmal ohne Schreiben gelaufen ist und sein Ergebnis auf dem
/// Bildschirm stand.
///
/// Übernommen wird **je Jahrgang**: `uebernehmen(jahrgang: 2022)` schickt eine
/// Datei mit nur diesem Jahrgang. Ein Jahrgang ist die Menge, die ein Mensch
/// prüfen kann, und er soll ihn abschließen können, ohne auf die übrigen zu
/// warten.
@injectable
class RegisterImportCubit extends Cubit<RegisterImportState> {
  final UseCase<RegisterImportDatei, LiesRegisterImportDateiParams> _liesDatei;
  final UseCase<RegisterImportBericht, ImportiereRegisterParams> _importiere;

  RegisterImportCubit(this._liesDatei, this._importiere)
    : super(const RegisterImportState());

  /// Liest die gewählte Datei und holt sofort die Vorschau dazu.
  Future<void> dateiWaehlen(String pfad) async {
    emit(state.zurueckgesetzt(dateiPfad: pfad, laufend: true));

    final gelesen = await _liesDatei(LiesRegisterImportDateiParams(pfad: pfad));
    if (isClosed) return;
    switch (gelesen) {
      case Left(value: final failure):
        emit(state.copyWith(laufend: false, fehler: failure.message));
      case Right(value: final datei):
        await _schicke(datei, uebernehmen: false);
    }
  }

  /// Der Ausschnitt, den der Anwalt ansieht. Voreingestellt ist „nur zu
  /// prüfen": Bei zweihundert Zeilen je Jahrgang ist die vollständige Liste
  /// keine Prüfung, sondern nur der Beweis, dass keine stattgefunden hat.
  void filtern(bool nurZuPruefen) =>
      emit(state.copyWith(nurZuPruefen: nurZuPruefen));

  /// Ersetzt eine Zeile durch die von Hand berichtigte Fassung und lässt neu
  /// prüfen. Was die Änderung bewirkt, sagt wieder der Dienst — hier wird nicht
  /// nachgerechnet, sonst gäbe es zwei Auslegungen derselben Regeln.
  Future<void> zeileErsetzen(
    int jahrgang,
    int zeile,
    RegisterImportZeile geaendert,
  ) => _mitGeaenderterDatei(jahrgang, zeile, (zeilen, stelle) {
    zeilen[stelle] = geaendert.copyWith(bearbeitet: true);
  });

  /// Nimmt eine Zeile aus dem Vorgang — für einen Eintrag, den der Erzeuger
  /// erfunden hat. Die Datei auf der Platte bleibt, wie sie ist.
  Future<void> zeileVerwerfen(int jahrgang, int zeile) => _mitGeaenderterDatei(
    jahrgang,
    zeile,
    (zeilen, stelle) => zeilen.removeAt(stelle),
  );

  /// Schreibt, was die Vorschau gezeigt hat: mit [jahrgang] nur diesen einen,
  /// ohne ihn die ganze Datei.
  Future<void> uebernehmen({int? jahrgang}) async {
    final datei = state.datei;
    if (datei == null || state.laufend) return;
    if (jahrgang == null && state.uebernommen) return;
    if (jahrgang != null && !state.kannJahrgangUebernehmen(jahrgang)) return;

    emit(state.copyWith(laufend: true, fehlerLoeschen: true));
    await _schicke(
      jahrgang == null ? datei : datei.nurJahrgang(jahrgang),
      uebernehmen: true,
      nurJahrgang: jahrgang,
    );
  }

  /// Zurück auf Anfang — für die nächste Datei.
  void zuruecksetzen() => emit(state.zurueckgesetzt());

  Future<void> _mitGeaenderterDatei(
    int jahrgang,
    int zeile,
    void Function(List<RegisterImportZeile> zeilen, int stelle) aendere,
  ) async {
    final datei = state.datei;
    if (datei == null || state.laufend) return;
    if (!state.kannJahrgangBearbeiten(jahrgang)) return;

    final eintrag = state.jahrgangAus(jahrgang);
    // Die Befunde zählen 1-basiert innerhalb ihres Jahrgangs.
    final stelle = zeile - 1;
    if (eintrag == null || stelle < 0 || stelle >= eintrag.zeilen.length) {
      return;
    }

    final zeilen = [...eintrag.zeilen];
    aendere(zeilen, stelle);

    emit(state.copyWith(laufend: true, fehlerLoeschen: true));
    await _schicke(
      datei.mitJahrgang(eintrag.mitZeilen(zeilen)),
      uebernehmen: false,
    );
  }

  /// Die geänderte Datei wird erst zum Zustand, wenn ihr Bericht da ist. Sonst
  /// zeigte die Liste einen Augenblick lang Zeilennummern aus dem alten Bericht
  /// über den Zeilen der neuen Datei — und ein Klick träfe die falsche Zeile.
  Future<void> _schicke(
    RegisterImportDatei gesendet, {
    required bool uebernehmen,
    int? nurJahrgang,
  }) async {
    final ergebnis = await _importiere(
      ImportiereRegisterParams(datei: gesendet, uebernehmen: uebernehmen),
    );
    if (isClosed) return;

    switch (ergebnis) {
      case Left(value: final failure):
        emit(state.copyWith(laufend: false, fehler: failure.message));
      case Right(value: final bericht):
        emit(
          nurJahrgang == null
              ? state.copyWith(
                  datei: gesendet,
                  bericht: bericht,
                  laufend: false,
                  fehlerLoeschen: true,
                  uebernommeneJahrgaenge: uebernehmen
                      ? {for (final jahr in gesendet.jahrgaenge) jahr.jahrgang}
                      : state.uebernommeneJahrgaenge,
                )
              : _nachEinzelnemJahrgang(nurJahrgang, bericht),
        );
    }
  }

  /// Der Stand nach der Übernahme eines einzelnen Jahrgangs: seine Karte wird
  /// durch das Ergebnis ersetzt, die übrigen bleiben stehen. Verschwänden sie,
  /// müsste der Anwalt die Datei für jeden weiteren Jahrgang neu einlesen.
  RegisterImportState _nachEinzelnemJahrgang(
    int jahrgang,
    RegisterImportBericht antwort,
  ) {
    final basis = state.bericht ?? antwort;
    final uebernommen = {...state.uebernommeneJahrgaenge, jahrgang};
    final inDerDatei = {
      for (final jahr in state.datei?.jahrgaenge ?? const []) jahr.jahrgang,
    };

    return state.copyWith(
      bericht: basis.mitJahrgang(
        antwort.jahrgaenge.firstWhere(
          (befund) => befund.jahrgang == jahrgang,
          orElse: () => JahrgangBefund(jahrgang: jahrgang),
        ),
        angewendet: uebernommen.containsAll(inDerDatei),
      ),
      uebernommeneJahrgaenge: uebernommen,
      laufend: false,
      fehlerLoeschen: true,
    );
  }
}
