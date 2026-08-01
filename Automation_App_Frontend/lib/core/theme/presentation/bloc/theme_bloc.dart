import 'package:automation_app/core/theme/data/local_theme_preferences_datasource.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'theme_event.dart';
part 'theme_state.dart';

/// Verwaltet die aktive Theme-Familie (Kanzlei / Standard) und den Hell-/
/// Dunkel-/System-Modus. Die Auswahl wird lokal persistiert, damit sie über
/// App-Starts hinweg erhalten bleibt.
@singleton
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final LocalThemePreferencesDatasource _datasource;

  ThemeBloc(this._datasource)
    : super(const ThemeState(ThemePreferences.defaults)) {
    on<LoadThemeEvent>(_onLoad);
    on<ChangeThemeModeEvent>(_onChangeMode);
    on<ChangeThemeVariantEvent>(_onChangeVariant);
  }

  Future<void> _onLoad(LoadThemeEvent event, Emitter<ThemeState> emit) async {
    final prefs = await _datasource.load();
    emit(ThemeState(prefs));
  }

  Future<void> _onChangeMode(
    ChangeThemeModeEvent event,
    Emitter<ThemeState> emit,
  ) async {
    await _persist(emit, state.preferences.copyWith(mode: event.mode));
  }

  Future<void> _onChangeVariant(
    ChangeThemeVariantEvent event,
    Emitter<ThemeState> emit,
  ) async {
    await _persist(emit, state.preferences.copyWith(variant: event.variant));
  }

  Future<void> _persist(Emitter<ThemeState> emit, ThemePreferences next) async {
    // Sofort anwenden, dann best-effort speichern: ein fehlgeschlagenes
    // Schreiben darf die bereits sichtbare Theme-Änderung nicht zurücknehmen.
    emit(ThemeState(next));
    try {
      await _datasource.save(next);
    } catch (_) {}
  }
}
