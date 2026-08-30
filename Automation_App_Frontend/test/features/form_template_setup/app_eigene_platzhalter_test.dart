import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Ausschlussliste der app-eigenen Platzhalter (#35 Teil 1): Was die App
/// beim Erzeugen selbst füllt, darf nie Eingabefeld oder Pflicht werden.
void main() {
  test('erkennt jeden app-eigenen Namen', () {
    for (final name in AppEigenePlatzhalter.namen) {
      expect(
        AppEigenePlatzhalter.istAppEigen(name),
        isTrue,
        reason: '$name füllt die App selbst',
      );
    }
  });

  test('vergleicht ohne Groß-/Kleinschreibung — wie die Backend-Ersetzung', () {
    expect(AppEigenePlatzhalter.istAppEigen('schadensaufstellung'), isTrue);
    expect(AppEigenePlatzhalter.istAppEigen('RVGNETTO'), isTrue);
    expect(AppEigenePlatzhalter.istAppEigen('  Gegenstandswert  '), isTrue);
  });

  test('gewöhnliche Feldnamen bleiben übernehmbar', () {
    expect(AppEigenePlatzhalter.istAppEigen('Kennzeichen'), isFalse);
    expect(AppEigenePlatzhalter.istAppEigen('Unfalldatum'), isFalse);
  });

  test('nur exakte Namen zählen — was das Backend nicht ersetzt, '
      'ist nicht app-eigen', () {
    // {{Rvg-Netto}} bliebe im Dokument stehen; der Anwalt muss so ein Feld
    // weiter anlegen dürfen (bzw. die Warnung „Platzhalter ohne Feld" sehen).
    expect(AppEigenePlatzhalter.istAppEigen('Rvg-Netto'), isFalse);
    expect(AppEigenePlatzhalter.istAppEigen('Rvg Netto'), isFalse);
  });
}
