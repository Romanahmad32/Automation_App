part of 'theme_bloc.dart';

@immutable
class ThemeState extends Equatable {
  final ThemePreferences preferences;

  const ThemeState(this.preferences);

  AppThemeVariant get variant => preferences.variant;

  ThemeMode get mode => preferences.mode;

  @override
  List<Object?> get props => [preferences];
}
