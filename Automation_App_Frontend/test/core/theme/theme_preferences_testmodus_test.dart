import 'dart:io';

import 'package:automation_app/core/theme/data/theme_preferences_datasource.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

/// Im E2E-Testmodus darf ein Lauf Schriftstufe und Erscheinungsbild der
/// installierten Anwendung nicht verstellen: die Datei liegt dann im
/// angegebenen Temp-Ordner und nicht im Anwendungsordner.
void main() {
  test('im Testmodus liegt theme_preferences.json im Testordner', () async {
    final ordner = await Directory.systemTemp.createTemp('theme_e2e_');
    addTearDown(() => ordner.delete(recursive: true));

    final datasource = await LocalThemePreferencesDatasource.create(
      PathProviderWindows(),
      testmodus: true,
      testmodusOrdner: Directory('${ordner.path}/unter'),
    );
    await datasource.save(ThemePreferences.defaults);

    expect(
      File('${ordner.path}/unter/theme_preferences.json').existsSync(),
      isTrue,
    );
    expect(
      (await datasource.load()).toJson(),
      ThemePreferences.defaults.toJson(),
    );
  });
}
