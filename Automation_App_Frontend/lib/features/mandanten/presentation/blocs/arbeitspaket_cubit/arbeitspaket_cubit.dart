import 'dart:io';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/kein_offener_ordner.dart';
import 'package:automation_app/features/mandanten/domain/services/arbeitspaket_bau.dart';
import 'package:automation_app/features/mandanten/domain/usecases/hole_arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/usecases/schreibe_arbeitspaket_datei.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_anleitung.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

part 'arbeitspaket_state.dart';

/// Führt die Arbeitspakete: Historie zeigen, das nächste Paket holen und als
/// Datei ablegen.
///
/// Die App ist hier der Buchhalter und der Erzeuger nur der Bearbeiter. Wer
/// über Tage und mehrere Sitzungen viertausend Ordner durchgeht, kann sich
/// nicht selbst merken, wo er aufgehört hat — und der Anwalt könnte es nicht
/// nachprüfen. Deshalb entsteht ein Paket nur über den Dienst, der es zugleich
/// in die Historie schreibt.
@injectable
class ArbeitspaketCubit extends Cubit<ArbeitspaketState> {
  final UseCase<List<Arbeitspaket>, NoParams> _getPakete;
  final UseCase<Arbeitspaket, HoleArbeitspaketParams> _holePaket;
  final UseCase<void, SchreibeArbeitspaketDateiParams> _schreibeDatei;

  ArbeitspaketCubit(this._getPakete, this._holePaket, this._schreibeDatei)
    : super(const ArbeitspaketState());

  /// Holt die Paket-Historie, neuestes zuerst.
  Future<void> laden() async {
    emit(state.copyWith(laufend: true, fehlerLoeschen: true));
    final ergebnis = await _getPakete(const NoParams());
    switch (ergebnis) {
      case Left(value: final failure):
        emit(state.copyWith(laufend: false, fehler: failure.message));
      case Right(value: final pakete):
        emit(
          state.copyWith(
            historie: pakete,
            laufend: false,
            fehlerLoeschen: true,
          ),
        );
    }
  }

  /// Holt ein Paket, baut die Datei und schreibt sie in den Ordner [zielPfad].
  /// Gibt das geholte Paket zurück oder null, wenn nichts zu holen war oder
  /// etwas schiefging (dann steht der Grund im Zustand).
  ///
  /// Zwei Arten von „null" sind zu unterscheiden: Ist kein Ordner mehr offen,
  /// antwortet der Dienst mit 409, und im Zustand steht `nichtsOffen` — das
  /// ist der Abschluss des Vorgangs und keine Störung. Alles andere landet in
  /// `fehler`.
  ///
  /// [zielPfad] ist der **Zielordner**, nicht der Dateiname: Wie das Paket
  /// heißt, steht erst fest, wenn der Dienst seine Nummer vergeben hat
  /// (`ArbeitspaketBau.dateiname`). Ein vorher gewählter Name wäre geraten und
  /// bei einem zweiten Anlauf falsch.
  ///
  /// [ordnernamen] sind **alle** gescannten Ordner — welche davon noch offen
  /// sind, entscheidet der Dienst. [mandanten] ist das Register, das als
  /// „bekannte Mandanten" mit in die Datei geht.
  Future<Arbeitspaket?> holeUndSchreibe({
    required List<String> ordnernamen,
    required int anzahl,
    required String zielPfad,
    required List<Mandant> mandanten,
  }) async {
    if (state.laufend) return null;
    emit(
      state.copyWith(laufend: true, nichtsOffen: false, fehlerLoeschen: true),
    );

    final Arbeitspaket paket;
    final geholt = await _holePaket(
      HoleArbeitspaketParams(ordnernamen: ordnernamen, anzahl: anzahl),
    );
    switch (geholt) {
      // Kein Ordner mehr offen: alles abgearbeitet. Das gehört nicht unter
      // „fehler" — sonst meldete die Oberfläche einen Defekt für den Umstand,
      // dass die Arbeit fertig ist.
      case Left(value: KeinOffenerOrdnerFailure()):
        emit(state.copyWith(laufend: false, nichtsOffen: true));
        return null;
      case Left(value: final failure):
        emit(state.copyWith(laufend: false, fehler: failure.message));
        return null;
      case Right(value: final wert):
        paket = wert;
    }

    final geschrieben = await _schreibeDatei(
      SchreibeArbeitspaketDateiParams(
        pfad: dateipfadIn(zielPfad, paket),
        inhalt: ArbeitspaketBau.alsText(
          paket: paket,
          mandanten: mandanten,
          anleitung: ImportAnleitung.paketText,
        ),
      ),
    );
    if (geschrieben case Left(value: final failure)) {
      emit(state.copyWith(laufend: false, fehler: failure.message));
      return null;
    }

    // Die Historie danach neu holen: Der Dienst hat das Paket eben erst
    // eingetragen, und die Stand-Anzeige soll es sofort zeigen — sonst stünde
    // dort „Paket 2" und im Explorer läge schon Paket 3.
    await laden();
    return paket;
  }

  /// Der volle Pfad der Paketdatei im gewählten Ordner. Ein abschließendes
  /// Trennzeichen wird abgestreift, damit kein doppeltes entsteht.
  static String dateipfadIn(String ordner, Arbeitspaket paket) {
    final basis = ordner.replaceAll(RegExp(r'[\\/]+$'), '');
    return '$basis${Platform.pathSeparator}${ArbeitspaketBau.dateiname(paket)}';
  }
}
