import 'package:automation_app/features/vorgaenge/domain/services/kennzeichen_normalisierung.dart';
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
}
