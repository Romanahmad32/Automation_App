import 'package:automation_app/core/aktualisierung/versions_vergleich.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionsVergleich', () {
    test('erkennt eine höhere Version an jeder Stelle', () {
      expect(VersionsVergleich.istNeuer('2.0.0', '1.9.9'), isTrue);
      expect(VersionsVergleich.istNeuer('1.1.0', '1.0.9'), isTrue);
      expect(VersionsVergleich.istNeuer('1.0.1', '1.0.0'), isTrue);
    });

    test('vergleicht Zahlen, nicht Zeichenketten', () {
      // Der Fehler, den ein naiver Vergleich macht: "1.10" steht alphabetisch
      // vor "1.9", die zehnte Auslieferung würde also nie gemeldet.
      expect(VersionsVergleich.istNeuer('1.10.0', '1.9.0'), isTrue);
      expect(VersionsVergleich.istNeuer('1.9.0', '1.10.0'), isFalse);
      expect(VersionsVergleich.istNeuer('1.0.10', '1.0.9'), isTrue);
    });

    test('dieselbe Version ist nicht neuer', () {
      expect(VersionsVergleich.istNeuer('1.0.0', '1.0.0'), isFalse);
      expect(VersionsVergleich.istNeuer('1.0.0', '1.0.1'), isFalse);
    });

    test('schneidet das v des Git-Tags und den Commit-Anhang ab', () {
      expect(VersionsVergleich.istNeuer('v1.0.1', '1.0.0+34888af'), isTrue);
      expect(VersionsVergleich.istNeuer('v1.0.0', '1.0.0+34888af'), isFalse);
    });

    test('meldet Unlesbares nie als Update', () {
      // Sonst schickt ein ungewöhnlicher Tag den Anwalt zu einem Download,
      // den er schon hat.
      expect(VersionsVergleich.istNeuer('release-2', '1.0.0'), isFalse);
      expect(VersionsVergleich.istNeuer('1.0', '1.0.0'), isFalse);
      expect(VersionsVergleich.istNeuer('1.0.0.1', '1.0.0'), isFalse);
      expect(VersionsVergleich.istNeuer('2.0.0', 'unbekannt'), isFalse);
    });
  });
}
