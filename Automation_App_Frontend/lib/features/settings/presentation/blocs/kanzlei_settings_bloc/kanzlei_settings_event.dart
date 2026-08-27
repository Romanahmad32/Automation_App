part of 'kanzlei_settings_bloc.dart';

sealed class KanzleiSettingsEvent extends Equatable {
  const KanzleiSettingsEvent();

  @override
  List<Object?> get props => [];
}

final class LoadKanzleiSettingsEvent extends KanzleiSettingsEvent {
  const LoadKanzleiSettingsEvent();
}

final class SaveKanzleiSettingsEvent extends KanzleiSettingsEvent {
  final KanzleiSettings settings;

  const SaveKanzleiSettingsEvent(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Speichert **nur** die Signatur und lässt die Kanzleidaten stehen. Eigenes
/// Ereignis, weil die beiden Formulare in verschiedenen Reitern liegen: Ein
/// Rundum-Speichern aus dem einen würde die ungespeicherten Änderungen des
/// anderen mit dem alten Stand überschreiben.
final class SaveMailSignaturEvent extends KanzleiSettingsEvent {
  final String signatur;

  const SaveMailSignaturEvent(this.signatur);

  @override
  List<Object?> get props => [signatur];
}
