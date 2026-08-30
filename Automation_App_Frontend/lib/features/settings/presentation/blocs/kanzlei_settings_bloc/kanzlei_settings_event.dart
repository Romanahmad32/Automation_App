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

/// Speichert **nur** die Titelzeilen-Farbe der Schadensaufstellung — aus dem
/// Einstellungs-Reiter „Schadensaufstellung", derselbe Zuschnitt wie bei der
/// Signatur: Das Feld liegt in einem anderen Reiter als die Kanzleidaten.
final class SaveTabellenkopfFarbeEvent extends KanzleiSettingsEvent {
  /// Farbwert als "RRGGBB", ohne '#'.
  final String farbeHex;

  const SaveTabellenkopfFarbeEvent(this.farbeHex);

  @override
  List<Object?> get props => [farbeHex];
}
