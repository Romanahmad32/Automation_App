import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:path_provider_windows/path_provider_windows.dart';

/// Lädt und speichert die Darstellungs-Einstellungen (Theme-Familie + Modus)
/// lokal als JSON im Anwendungsordner — analog zu den Kanzlei-Einstellungen,
/// inklusive atomarem Schreiben mit `.bak`-Rücksicherung.
abstract class LocalThemePreferencesDatasource {
  Future<ThemePreferences> load();

  Future<ThemePreferences> save(ThemePreferences preferences);
}

class LocalThemePreferencesDatasourceImpl
    implements LocalThemePreferencesDatasource {
  final File _file;

  LocalThemePreferencesDatasourceImpl._({required File file}) : _file = file;

  static Future<LocalThemePreferencesDatasourceImpl> create(
    PathProviderWindows pathProviderWindows,
  ) async {
    final String? supportPath = await pathProviderWindows
        .getApplicationSupportPath();
    if (supportPath == null) {
      throw const SettingsException('Kein Anwendungsordner gefunden');
    }
    final file = File('$supportPath/theme_preferences.json');
    return LocalThemePreferencesDatasourceImpl._(file: file);
  }

  @override
  Future<ThemePreferences> load() async {
    // Noch nie gespeichert: Werkseinstellung (Variante A) zurückgeben.
    if (!await _file.exists()) {
      final backup = File('${_file.path}.bak');
      if (!await backup.exists()) {
        return ThemePreferences.defaults;
      }
      await backup.rename(_file.path);
    }

    try {
      final decoded = jsonDecode(await _file.readAsString());
      return ThemePreferences.fromJson(decoded as Map<String, dynamic>);
    } catch (_) {
      // Beschädigte Datei darf das App-Theme nicht blockieren — auf die
      // Werkseinstellung zurückfallen statt einen Fehler zu werfen.
      return ThemePreferences.defaults;
    }
  }

  @override
  Future<ThemePreferences> save(ThemePreferences preferences) async {
    await _writeAtomically(preferences);
    return preferences;
  }

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  Future<void> _writeAtomically(ThemePreferences preferences) async {
    final tmp = File('${_file.path}.tmp');
    final backup = File('${_file.path}.bak');
    try {
      await tmp.writeAsString(
        _encoder.convert(preferences.toJson()),
        flush: true,
      );

      // Auf Windows schlägt File.rename fehl, wenn das Ziel bereits existiert.
      if (await _file.exists()) {
        if (await backup.exists()) await backup.delete();
        await _file.rename(backup.path);
      }
      try {
        await tmp.rename(_file.path);
      } catch (_) {
        if (await backup.exists()) await backup.rename(_file.path);
        rethrow;
      }
      try {
        if (await backup.exists()) await backup.delete();
      } catch (_) {}
    } catch (e) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}
