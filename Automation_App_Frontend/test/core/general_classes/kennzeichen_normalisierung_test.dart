import 'package:automation_app/core/general_classes/kennzeichen_normalisierung.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalisiert Schreibvarianten in die Domänen-Konvention', () {
    expect(normalizeKennzeichen('gg-xy123'), 'GG-XY 123');
    expect(normalizeKennzeichen('GG XY 123'), 'GG-XY 123');
    expect(normalizeKennzeichen('  HG-E 1427 '), 'HG-E 1427');
    expect(normalizeKennzeichen('HG-E1427H'), 'HG-E 1427H');
  });

  test('lässt nicht erkennbare Schreibweisen (bereinigt) unverändert', () {
    expect(normalizeKennzeichen('kein kennzeichen'), 'kein kennzeichen');
    expect(normalizeKennzeichen(null), isNull);
    expect(normalizeKennzeichen('   '), '   ');
  });

  test('gleichesKennzeichen vergleicht tolerant, aber nie leer gegen leer', () {
    expect(gleichesKennzeichen('gg-xy123', 'GG XY 123'), isTrue);
    expect(gleichesKennzeichen('GG-XY 123', 'GG-XY 322'), isFalse);
    expect(gleichesKennzeichen(null, 'GG-XY 123'), isFalse);
    expect(gleichesKennzeichen(null, null), isFalse);
  });

  group('istKennzeichen', () {
    /// Dieselbe Toleranz wie [normalizeKennzeichen]: Was sich in die
    /// Konvention überführen lässt, ist ein Kennzeichen. Liefen die beiden
    /// auseinander, beanstandete das Formular einen Wert, den die App selbst
    /// aus dem Register angeboten hat.
    test('erkennt jede Schreibweise, die normalisiert werden kann', () {
      for (final wert in [
        'HG-E 1427',
        'hg-e 1427',
        'HGE1427',
        'GG XY 123',
        '  HG-E 1427 ',
        'HG-E1427H',
        'B-A 1',
      ]) {
        expect(istKennzeichen(wert), isTrue, reason: wert);
      }
    });

    test('leer und null sind kein Kennzeichen', () {
      expect(istKennzeichen(null), isFalse);
      expect(istKennzeichen(''), isFalse);
      expect(istKennzeichen('   '), isFalse);
    });

    test('was kein Kennzeichen ist, wird nicht dazu erklärt', () {
      for (final wert in [
        'kein kennzeichen',
        'HG-E',
        '1427',
        'HGEF-XY 1427',
        'HG-E 12345',
        'HG-E 1427X',
      ]) {
        expect(istKennzeichen(wert), isFalse, reason: wert);
      }
    });
  });
}
