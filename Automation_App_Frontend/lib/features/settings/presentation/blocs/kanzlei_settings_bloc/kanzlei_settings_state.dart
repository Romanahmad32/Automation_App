part of 'kanzlei_settings_bloc.dart';

/// Welcher Teil der Einstellungen zuletzt gespeichert wurde.
///
/// Kanzleidaten und Signatur hängen am selben Einstellungssatz, stehen aber in
/// verschiedenen Reitern — die Signatur beim E-Mail-Zugang, wo sie hingehört.
/// Ohne diese Unterscheidung meldete das eine Formular den Erfolg des anderen.
enum KanzleiSettingsBereich { kanzlei, signatur, schadensaufstellung }

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

  /// Gesetzt direkt nach erfolgreichem Speichern — und zwar auf den Bereich,
  /// dessen Formular gespeichert hat (für dessen Bestätigungsmeldung).
  final KanzleiSettingsBereich? gespeichert;

  const KanzleiSettingsLoaded(this.settings, {this.gespeichert});

  @override
  List<Object?> get props => [settings, gespeichert];
}

final class KanzleiSettingsError extends KanzleiSettingsState {
  final String message;

  const KanzleiSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}
