import 'package:automation_app/core/theme/data/theme_preferences_datasource.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';

/// Ersetzt die JSON-Datei im Anwendungsordner durch ein Feld im Speicher.
///
/// Der echte `LocalThemePreferencesDatasource` braucht einen
/// `PathProviderWindows` und schreibt in einen Ordner, den es im Test nicht
/// gibt. Hier steht stattdessen, was der `ThemeBloc` tatsächlich von seiner
/// Quelle braucht: einen Stand zum Laden und eine Stelle, die mitschreibt, was
/// gespeichert wurde.
///
/// Liegt neben den Tests und nicht in jedem einzelnen, weil ihn sowohl der
/// Bloc-Test als auch der Widgettest des Reiters „Darstellung" braucht — und
/// zwei Kopien desselben Doubles laufen beim nächsten Feld auseinander.
class MerkenderThemeSpeicher implements ThemePreferencesDatasource {
  /// Was [load] liefert. Standard ist die Werkseinstellung — derselbe Stand,
  /// mit dem der Bloc ohnehin startet.
  ThemePreferences stand;

  /// Jeder Aufruf von [save], in der Reihenfolge des Eintreffens.
  final List<ThemePreferences> gespeichert = [];

  /// Lässt [save] scheitern. Für den Fall, dass die Datei nicht schreibbar
  /// ist: Die bereits sichtbare Änderung darf davon nicht zurückgenommen
  /// werden.
  bool speichernSchlaegtFehl = false;

  MerkenderThemeSpeicher({this.stand = ThemePreferences.defaults});

  @override
  Future<ThemePreferences> load() async => stand;

  @override
  Future<ThemePreferences> save(ThemePreferences preferences) async {
    if (speichernSchlaegtFehl) {
      throw Exception('Anwendungsordner nicht beschreibbar');
    }
    gespeichert.add(preferences);
    stand = preferences;
    return preferences;
  }
}
