import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'kanzlei_settings_event.dart';

part 'kanzlei_settings_state.dart';

@injectable
class KanzleiSettingsBloc
    extends Bloc<KanzleiSettingsEvent, KanzleiSettingsState> {
  final UseCase<KanzleiSettings, NoParams> _getSettings;
  final UseCase<KanzleiSettings, KanzleiSettings> _saveSettings;

  KanzleiSettingsBloc(this._getSettings, this._saveSettings)
    : super(const KanzleiSettingsLoading()) {
    on<LoadKanzleiSettingsEvent>(_onLoad);
    on<SaveKanzleiSettingsEvent>(_onSave);
    on<SaveMailSignaturEvent>(_onSaveSignatur);
    on<SaveTabellenkopfFarbeEvent>(_onSaveTabellenkopfFarbe);
  }

  Future<void> _onLoad(
    LoadKanzleiSettingsEvent event,
    Emitter<KanzleiSettingsState> emit,
  ) async {
    emit(const KanzleiSettingsLoading());
    final result = await _getSettings(const NoParams());
    switch (result) {
      case Right(value: final settings):
        emit(KanzleiSettingsLoaded(settings));
      case Left(value: final failure):
        emit(KanzleiSettingsError(failure.message));
    }
  }

  Future<void> _onSave(
    SaveKanzleiSettingsEvent event,
    Emitter<KanzleiSettingsState> emit,
  ) => _speichere(event.settings, KanzleiSettingsBereich.kanzlei, emit);

  /// Die Signatur steht im E-Mail-Reiter und wird dort einzeln gespeichert.
  /// Sie wird in den zuletzt geladenen Stand hineinkopiert, damit die
  /// Kanzleidaten daneben unberührt bleiben.
  Future<void> _onSaveSignatur(
    SaveMailSignaturEvent event,
    Emitter<KanzleiSettingsState> emit,
  ) async {
    final aktuell = state;
    if (aktuell is! KanzleiSettingsLoaded) return;

    return _speichere(
      aktuell.settings.copyWith(mailSignatur: event.signatur),
      KanzleiSettingsBereich.signatur,
      emit,
    );
  }

  /// Die Titelzeilen-Farbe steht im Reiter „Schadensaufstellung" und wird dort
  /// einzeln gespeichert — hineinkopiert in den zuletzt geladenen Stand, damit
  /// die Kanzleidaten und die Signatur daneben unberührt bleiben.
  Future<void> _onSaveTabellenkopfFarbe(
    SaveTabellenkopfFarbeEvent event,
    Emitter<KanzleiSettingsState> emit,
  ) async {
    final aktuell = state;
    if (aktuell is! KanzleiSettingsLoaded) return;

    return _speichere(
      aktuell.settings.copyWith(tabellenkopfFarbeHex: event.farbeHex),
      KanzleiSettingsBereich.schadensaufstellung,
      emit,
    );
  }

  Future<void> _speichere(
    KanzleiSettings settings,
    KanzleiSettingsBereich bereich,
    Emitter<KanzleiSettingsState> emit,
  ) async {
    emit(const KanzleiSettingsLoading());
    final result = await _saveSettings(settings);
    switch (result) {
      case Right(value: final gespeichert):
        emit(KanzleiSettingsLoaded(gespeichert, gespeichert: bereich));
      case Left(value: final failure):
        emit(KanzleiSettingsError(failure.message));
    }
  }
}
