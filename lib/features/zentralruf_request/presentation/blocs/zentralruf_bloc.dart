import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'zentralruf_event.dart';
part 'zentralruf_state.dart';

@injectable
class ZentralrufBloc extends Bloc<ZentralrufEvent, ZentralrufState> {
  final UseCase<ZentralrufPrefillResult, ZentralrufRequest> prefillForm;
  final UseCase<KanzleiSettings, NoParams> _getKanzleiSettings;
  final UseCase<KanzleiSettings, KanzleiSettings> _saveKanzleiSettings;
  final VorgangCubit _vorgaenge;

  ZentralrufBloc(
    this.prefillForm,
    this._getKanzleiSettings,
    this._saveKanzleiSettings,
    this._vorgaenge,
  ) : super(ZentralrufInitial()) {
    on<LoadZentralrufDefaultsEvent>(_onLoadDefaults);
    on<PrefillZentralrufFormEvent>(_onPrefillFormEvent);
    on<ErhoeheAuftragsnummerEvent>(_onErhoeheAuftragsnummer);
  }

  Future<void> _onLoadDefaults(
    LoadZentralrufDefaultsEvent event,
    Emitter<ZentralrufState> emit,
  ) async {
    final settings = await _ladeEinstellungen();
    if (settings != null) {
      emit(
        ZentralrufDefaultsLoaded(
          auftragsnummer: settings.laufendeAuftragsnummer,
          abteilung: settings.abteilung,
        ),
      );
    }
    // Bei Fehler bleibt es bei den Formular-Standardwerten.
  }

  Future<void> _onPrefillFormEvent(
    PrefillZentralrufFormEvent event,
    Emitter<ZentralrufState> emit,
  ) async {
    emit(ZentralrufLoading());

    // Kanzleidaten aus den Einstellungen anhängen. Schlägt das Laden fehl,
    // wird ohne Anfragerblock gesendet (Backend nutzt dann seinen Fallback).
    final settings = await _ladeEinstellungen();
    final request = settings == null
        ? event.request
        : event.request.copyWith(anfrager: _toAnfrager(settings));
    final result = await prefillForm(request);

    switch (result) {
      case Left(value: final failure):
        emit(ZentralrufError(failure.message));
      case Right(value: final prefillResult):
        // Den Vorgang als gemeinsame Klammer anlegen/aktualisieren: er hält die
        // Verknüpfung zum Mandanten, das Rechtsgebiet und später Antwort,
        // Dokument und Ablage zusammen, damit die Daten wiederverwendet werden.
        await _vorgaenge.registriereAnfrage(
          prefillResult.referenz,
          rechtsgebiet: event.rechtsgebiet,
          mandantId: event.mandantId,
          mandantName: event.mandantName,
        );

        // Fortzählung der laufenden Auftragsnummer (Req. 3.2): ohne
        // Einstellungen kein Vorschlag; im Automatik-Modus direkt erhöhen,
        // sonst dem Anwalt zur Bestätigung vorschlagen.
        if (settings == null) {
          emit(ZentralrufPrefillSuccess(prefillResult));
          return;
        }
        final naechste = settings.laufendeAuftragsnummer + 1;
        if (settings.auftragsnummerAutomatischErhoehen) {
          await _saveKanzleiSettings(
            settings.copyWith(laufendeAuftragsnummer: naechste),
          );
          emit(
            ZentralrufPrefillSuccess(
              prefillResult,
              auftragsnummerErhoehtAuf: naechste,
            ),
          );
        } else {
          emit(
            ZentralrufPrefillSuccess(
              prefillResult,
              auftragsnummerVorschlag: naechste,
            ),
          );
        }
    }
  }

  Future<void> _onErhoeheAuftragsnummer(
    ErhoeheAuftragsnummerEvent event,
    Emitter<ZentralrufState> emit,
  ) async {
    final settings = await _ladeEinstellungen();
    if (settings == null) return;

    // Absolut setzen statt zu addieren → mehrfaches Bestätigen bleibt idempotent.
    await _saveKanzleiSettings(
      settings.copyWith(laufendeAuftragsnummer: event.neueNummer),
    );
    emit(ZentralrufAuftragsnummerErhoeht(event.neueNummer));
  }

  Future<KanzleiSettings?> _ladeEinstellungen() async {
    final result = await _getKanzleiSettings(const NoParams());
    return switch (result) {
      Right(value: final settings) => settings,
      Left() => null,
    };
  }

  ZentralrufAnfrager _toAnfrager(KanzleiSettings settings) =>
      ZentralrufAnfrager(
        personentyp: settings.personentyp,
        name: settings.name,
        strasseHausnummer: settings.strasseHausnummer,
        postleitzahl: settings.postleitzahl,
        ort: settings.ort,
        emailAdresse: settings.emailAdresse,
        telefonnummer: settings.telefonnummer,
      );
}
