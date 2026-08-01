part of 'kanzlei_settings_bloc.dart';

sealed class KanzleiSettingsState extends Equatable {
  const KanzleiSettingsState();

  @override
  List<Object?> get props => [];
}

final class KanzleiSettingsLoading extends KanzleiSettingsState {
  const KanzleiSettingsLoading();
}

final class KanzleiSettingsLoaded extends KanzleiSettingsState {
  final KanzleiSettings settings;

  /// True direkt nach erfolgreichem Speichern (für eine Bestätigungsmeldung).
  final bool justSaved;

  const KanzleiSettingsLoaded(this.settings, {this.justSaved = false});

  @override
  List<Object?> get props => [settings, justSaved];
}

final class KanzleiSettingsError extends KanzleiSettingsState {
  final String message;

  const KanzleiSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
