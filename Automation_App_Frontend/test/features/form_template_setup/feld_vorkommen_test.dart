import 'package:automation_app/features/form_template_setup/domain/services/feld_vorkommen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Kennzeichen je Feld (#35 Teil 3): In welcher Word-Datei kommt der
/// Feldname als Platzhalter vor?
void main() {
  test('ordnet die vier Fälle zu', () {
    const ohne = {'Kennzeichen', 'Frist'};
    const mit = {'Kennzeichen', 'Schadenshoehe'};

    FeldVorkommen? bestimme(String name) =>
        FeldVorkommen.bestimme(name, ohneAuflistung: ohne, mitAuflistung: mit);

    expect(bestimme('Kennzeichen'), FeldVorkommen.beide);
    expect(bestimme('Frist'), FeldVorkommen.nurHgn);
    expect(bestimme('Schadenshoehe'), FeldVorkommen.nurAuflistung);
    expect(bestimme('Vertipptt'), FeldVorkommen.inKeinerDatei);
  });

  test('vergleicht ohne Groß-/Kleinschreibung — wie die Backend-Ersetzung', () {
    expect(
      FeldVorkommen.bestimme(
        'zahlungsfrist',
        ohneAuflistung: const {'Zahlungsfrist'},
        mitAuflistung: null,
      ),
      FeldVorkommen.nurHgn,
    );
  });

  test(
    'ohne bekannte Platzhalter oder ohne Namen gibt es kein Kennzeichen',
    () {
      expect(
        FeldVorkommen.bestimme(
          'Kennzeichen',
          ohneAuflistung: null,
          mitAuflistung: null,
        ),
        isNull,
      );
      expect(
        FeldVorkommen.bestimme(
          '  ',
          ohneAuflistung: const {'Kennzeichen'},
          mitAuflistung: null,
        ),
        isNull,
      );
    },
  );
}
