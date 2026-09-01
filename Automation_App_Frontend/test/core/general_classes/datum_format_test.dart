import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zeitpunkt = DateTime(2026, 9, 1, 14, 12);

  group('deutschesDatum', () {
    test('formatiert mit führenden Nullen', () {
      expect(deutschesDatum(zeitpunkt), '01.09.2026');
    });

    test('padded Tag und Monat auch bei einstelligen Werten', () {
      expect(deutschesDatum(DateTime(2026, 1, 5)), '05.01.2026');
    });
  });

  group('deutscheUhrzeit', () {
    test('formatiert Stunde und Minute ohne Sekunden', () {
      expect(deutscheUhrzeit(zeitpunkt), '14:12');
    });

    test('padded einstellige Stunden und Minuten', () {
      expect(deutscheUhrzeit(DateTime(2026, 9, 1, 4, 5)), '04:05');
    });
  });

  group('deutschesDatumMitUhrzeit', () {
    test('kombiniert Datum und Uhrzeit mit Leerzeichen', () {
      expect(deutschesDatumMitUhrzeit(zeitpunkt), '01.09.2026 14:12');
    });
  });

  group('isoDatum', () {
    test('formatiert JJJJ-MM-TT', () {
      expect(isoDatum(zeitpunkt), '2026-09-01');
    });
  });
}
