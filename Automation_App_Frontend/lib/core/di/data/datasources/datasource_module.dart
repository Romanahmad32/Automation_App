import 'package:automation_app/core/theme/data/theme_preferences_datasource.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

@module
abstract class DatasourceModule {
  // Nur noch die Theme-Präferenz bleibt lokal (reine UI-Einstellung). Alle
  // fachlichen Daten liegen jetzt im Backend (SQLite) und werden über die
  // jeweiligen HTTP-Datasources gelesen/geschrieben.
  @preResolve
  Future<ThemePreferencesDatasource> get localThemePreferencesDatasource =>
      LocalThemePreferencesDatasource.create(PathProviderWindows());
}
