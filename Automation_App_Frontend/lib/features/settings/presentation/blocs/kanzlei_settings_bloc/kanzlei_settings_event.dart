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
