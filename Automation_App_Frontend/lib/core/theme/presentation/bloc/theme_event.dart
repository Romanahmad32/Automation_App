part of 'theme_bloc.dart';

@immutable
sealed class ThemeEvent {}

/// Lädt die persistierten Darstellungs-Einstellungen beim App-Start.
final class LoadThemeEvent extends ThemeEvent {}

/// Wechselt den Hell-/Dunkel-/System-Modus innerhalb der aktiven Theme-Familie.
final class ChangeThemeModeEvent extends ThemeEvent {
  final ThemeMode mode;

  ChangeThemeModeEvent(this.mode);
}

/// Wechselt die Theme-Familie (Kanzlei-Design / Standard).
final class ChangeThemeVariantEvent extends ThemeEvent {
  final AppThemeVariant variant;

  ChangeThemeVariantEvent(this.variant);
}
