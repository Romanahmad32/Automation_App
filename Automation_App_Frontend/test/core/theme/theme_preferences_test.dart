import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/domain/theme_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Darstellungs-Einstellungen liegen als JSON im Anwendungsordner und
/// werden bei **jedem** App-Start gelesen. Diese Datei überlebt Updates —
/// jede, die vor Issue #57 geschrieben wurde, kennt den Schlüssel
/// `schriftstufe` nicht.
///
/// Warum das eine eigene Prüfung wert ist: `LocalThemePreferencesDatasource`
/// fängt jeden Lesefehler ab und fällt auf die Werkseinstellung zurück. Ein
/// Sturz beim Lesen sähe deshalb nicht nach einem Fehler aus, sondern nach
/// „Design und Modus sind nach dem Update zurückgesetzt" — ein Verhalten, dem
/// niemand ansieht, dass es einen Grund hat. Das Gegenteil davon steht hier.
void main() {
  const stand = ThemePreferences(
    variant: AppThemeVariant.standard,
    mode: ThemeMode.dark,
    schriftstufe: Schriftstufe.amGroessten,
  );

  group('fromJson', () {
    test('eine Datei ohne Schriftstufe behaelt Variante und Modus', () {
      final gelesen = ThemePreferences.fromJson({
        'variant': 'standard',
        'mode': 'dark',
      });

      expect(gelesen.schriftstufe, Schriftstufe.vorgabe);
      expect(
        gelesen.variant,
        AppThemeVariant.standard,
        reason:
            'Der fehlende neue Schlüssel darf die alten nicht mitreißen — '
            'genau das wäre passiert, wenn fromJson darüber stürzt.',
      );
      expect(gelesen.mode, ThemeMode.dark);
    });

    test('ein unbekannter Wert faellt auf die Vorgabe zurueck', () {
      // Von Hand bearbeitet, oder eine Stufe aus einer neueren Fassung der
      // App nach einem Downgrade. Beides ist kein Grund, die Datei zu
      // verwerfen.
      final gelesen = ThemePreferences.fromJson({
        'variant': 'kanzlei',
        'mode': 'system',
        'schriftstufe': 'riesig',
      });

      expect(gelesen.schriftstufe, Schriftstufe.vorgabe);
    });

    test('eine leere Datei ergibt die Werkseinstellung', () {
      expect(ThemePreferences.fromJson(const {}), ThemePreferences.defaults);
    });
  });

  test('jede Stufe uebersteht den Weg durch das JSON', () {
    for (final stufe in Schriftstufe.values) {
      final geschrieben = stand.copyWith(schriftstufe: stufe).toJson();
      final gelesen = ThemePreferences.fromJson(geschrieben);

      expect(
        gelesen.schriftstufe,
        stufe,
        reason: 'Stufe ${stufe.name} kommt als ${gelesen.schriftstufe} zurück',
      );
      // Gleichheit über Equatable: Wer `props` beim nächsten Feld vergisst,
      // baut einen Bloc, der eine Änderung nicht mehr als Änderung sieht.
      expect(gelesen, stand.copyWith(schriftstufe: stufe));
    }
  });

  test('copyWith laesst die anderen Felder in Ruhe', () {
    final geaendert = stand.copyWith(schriftstufe: Schriftstufe.normal);

    expect(geaendert.schriftstufe, Schriftstufe.normal);
    expect(geaendert.variant, stand.variant);
    expect(geaendert.mode, stand.mode);
  });
}
