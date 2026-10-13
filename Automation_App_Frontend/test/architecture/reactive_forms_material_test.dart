import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Verbietet die Material-Widgets von `reactive_forms` (Issue #185).
///
/// Hintergrund: Die App läuft auf `package:material_ui/material_ui.dart`.
/// `ReactiveTextField`, `ReactiveDropdownField` & Co. aus `reactive_forms`
/// bauen aber noch das **alte** Material aus `package:flutter/material.dart` —
/// das Paket kennt material_ui nicht. Der Fehler zeigt sich nicht beim
/// Übersetzen, sondern erst zur Laufzeit: Die alten Widgets suchen ein altes
/// `Theme` bzw. `MaterialLocalizations` und scheitern dort.
///
/// Stattdessen: `ReactiveTextEingabe` (`lib/core/general_widgets/form/`) bzw.
/// `ReactiveFormField` mit einem material_ui-Widget als Kind.
///
/// Geprüft wird in `lib/` und `test/`; reine Kommentarzeilen zählen nicht, weil
/// Doc-Kommentare die verbotenen Namen erklärend nennen dürfen.
void main() {
  // Namentliche Ausnahmen. **Bleibt leer** — ein Eintrag wäre die Laufzeitfalle
  // unter neuem Namen (Vorbild: `rueckmeldung_test.dart`).
  const ausnahmen = <String>{};

  final verboten = RegExp(
    r'\bReactive(TextField|DropdownField|SwitchListTile|Switch|CheckboxListTile|'
    r'Checkbox|RadioListTile|Radio|Slider|DatePicker|TimePicker)\b',
  );

  test('weder lib/ noch test/ verwenden die Material-Widgets von '
      'reactive_forms', () {
    final verstoesse = <String>[];

    for (final datei in [
      ...dartQuelldateien('lib'),
      ...dartQuelldateien('test'),
    ]) {
      final pfad = relPfad(datei);
      if (ausnahmen.contains(pfad)) continue;
      // Dieser Test nennt die Namen selbst.
      if (pfad.endsWith('architecture/reactive_forms_material_test.dart')) {
        continue;
      }

      var nr = 0;
      for (final zeile in datei.readAsLinesSync()) {
        nr++;
        if (zeile.trimLeft().startsWith('//')) continue;
        final treffer = verboten.firstMatch(zeile);
        if (treffer != null) verstoesse.add('$pfad:$nr: ${treffer.group(0)}');
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'reactive_forms-Widgets bauen altes Material und scheitern erst zur '
          'Laufzeit (Issue #185). Stattdessen ReactiveTextEingabe bzw. '
          'ReactiveFormField + material_ui-Widget:\n  '
          '${verstoesse.join('\n  ')}',
    );
  });
}
