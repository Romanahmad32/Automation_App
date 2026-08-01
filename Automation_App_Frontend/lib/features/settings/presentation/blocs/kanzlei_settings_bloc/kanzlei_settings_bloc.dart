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
  }

  Future<void> _onLoad(LoadKanzleiSettingsEvent event,
      Emitter<KanzleiSettingsState> emit,) async {
    emit(const KanzleiSettingsLoading());
    final result = await _getSettings(const NoParams());
    switch (result) {
      case Right(value: final settings):
        emit(KanzleiSettingsLoaded(settings));
      case Left(value: final failure):
        emit(KanzleiSettingsError(failure.message));
    }
  }

  Future<void> _onSave(SaveKanzleiSettingsEvent event,
      Emitter<KanzleiSettingsState> emit,) async {
    emit(const KanzleiSettingsLoading());
    final result = await _saveSettings(event.settings);
    switch (result) {
      case Right(value: final settings):
        emit(KanzleiSettingsLoaded(settings, justSaved: true));
      case Left(value: final failure):
        emit(KanzleiSettingsError(failure.message));
    }
  }
}
