import 'package:automation_app/core/general_classes/dateigroesse_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatiereDateigroesse', () {
    test('Grenzfall 0 Byte', () {
      expect(formatiereDateigroesse(0), '0 Bytes');
    });

    test('unter 1 KB bleibt in Bytes', () {
      expect(formatiereDateigroesse(500), '500 Bytes');
      expect(formatiereDateigroesse(1023), '1023 Bytes');
    });

    test('KB werden gerundet, ohne Nachkommastelle', () {
      expect(formatiereDateigroesse(2048), '2 KB');
      expect(formatiereDateigroesse(1536), '2 KB');
    });

    test('MB mit deutschem Komma statt Punkt', () {
      expect(formatiereDateigroesse(2516582), '2,4 MB');
      expect(formatiereDateigroesse(10 * 1024 * 1024), '10,0 MB');
    });

    test('GB mit deutschem Komma statt Punkt', () {
      expect(formatiereDateigroesse(2 * 1024 * 1024 * 1024), '2,0 GB');
      expect(
        formatiereDateigroesse((2.5 * 1024 * 1024 * 1024).round()),
        '2,5 GB',
      );
    });
  });
}
