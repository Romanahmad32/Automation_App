import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_uebernahme.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die eine Stelle, die über das Übernehmen eines Platzhalters entscheidet
/// (#35 Teil 1): app-eigene nie, Namensgleiche nie, alles andere ja.
void main() {
  test('app-eigene Platzhalter werden abgelehnt', () {
    final grund = PlatzhalterUebernahme.ablehnungsgrund(
      'Schadensaufstellung',
      const [],
    );

    expect(grund, contains('füllt die App'));
  });

  test('ein namensgleiches Feld wird abgelehnt — ohne Groß-/Kleinschreibung '
      'und Randleerzeichen', () {
    final grund = PlatzhalterUebernahme.ablehnungsgrund('Kennzeichen', const [
      ' kennzeichen ',
    ]);

    expect(grund, contains('existiert bereits'));
  });

  test('ein neuer gewöhnlicher Platzhalter wird übernommen', () {
    final grund = PlatzhalterUebernahme.ablehnungsgrund('Kennzeichen', const [
      'Unfalldatum',
      null,
    ]);

    expect(grund, isNull);
  });

  group('„Alle übernehmen" (uebernehmbare)', () {
    test('erzeugt kein Feld für {{Schadensaufstellung}} und die '
        'RVG-Platzhalter', () {
      final ergebnis = PlatzhalterUebernahme.uebernehmbare(const [
        'Kennzeichen',
        'Schadensaufstellung',
        'RvgBrutto',
        'Unfalldatum',
      ], const []);

      expect(ergebnis, ['Kennzeichen', 'Unfalldatum']);
    });

    test('überspringt Namensgleiche und Doppelte, hält die '
        'Dokumentreihenfolge', () {
      final ergebnis = PlatzhalterUebernahme.uebernehmbare(
        const ['Frist', 'Kennzeichen', 'frist', 'Unfalldatum'],
        const ['kennzeichen '],
      );

      expect(ergebnis, ['Frist', 'Unfalldatum']);
    });
  });

  test('istUebernommen vergleicht ohne Groß-/Kleinschreibung', () {
    expect(
      PlatzhalterUebernahme.istUebernommen('Kennzeichen', const [
        ' kennzeichen',
      ]),
      isTrue,
    );
    expect(
      PlatzhalterUebernahme.istUebernommen('Frist', const ['Kennzeichen']),
      isFalse,
    );
  });
}
