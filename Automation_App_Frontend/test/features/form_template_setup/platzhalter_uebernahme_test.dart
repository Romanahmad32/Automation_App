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
}
