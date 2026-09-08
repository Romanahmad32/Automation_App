import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_jahrgang.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Jahrgang ist die Überschrift, unter der eine Zeile im Register steht.
///
/// Seit Issue #109 baut das Backend die Zeilen der Registerseite selbst; diese
/// Rechnung braucht nur noch die Startseiten-Karte, die ihre Zeilen aus dem
/// geladenen Vorgangsbestand baut. Weicht sie von
/// `RegisterZeilenBau.Jahrgang` ab, sortiert die Startseite einen Vorgang
/// unter ein anderes Jahr als die Registerseite daneben — das Gegenstück im
/// Backend ist `RegisterZeilenBauTests.Jahrgang_NimmtNurZiffern`.
void main() {
  Vorgang vorgang({
    String? jahr = '26',
    DateTime? angefragtAm,
    DateTime? abgeschlossenAm,
    VorgangStatus status = VorgangStatus.versendet,
  }) => Vorgang(
    referenz: '01/26 C03_HG-E 1427',
    angefragtAm: angefragtAm ?? DateTime(2026, 1, 5),
    status: status,
    laufendeNummer: 1,
    jahr: jahr,
    abteilung: 'C03',
    abgeschlossenAm: abgeschlossenAm,
  );

  test('macht aus dem zweistelligen Jahr die vierstellige Überschrift', () {
    expect(VorgangJahrgang.fuer(vorgang(jahr: '26')), '2026');
  });

  test('nimmt ein bereits vierstelliges Jahr unverändert', () {
    expect(VorgangJahrgang.fuer(vorgang(jahr: '2024')), '2024');
  });

  test('fällt ohne Jahresfeld auf das Abschlussdatum zurück', () {
    final ohneJahr = vorgang(
      jahr: null,
      angefragtAm: DateTime(2025, 12, 30),
      abgeschlossenAm: DateTime(2026, 1, 8),
    );

    expect(VorgangJahrgang.fuer(ohneJahr), '2026');
  });

  test('nimmt ohne Abschluss das Anfragedatum', () {
    final offen = vorgang(
      jahr: null,
      status: VorgangStatus.angefragt,
      angefragtAm: DateTime(2024, 3, 7),
    );

    expect(VorgangJahrgang.fuer(offen), '2024');
  });

  /// `int.tryParse` nahm das Vorzeichen an und machte aus „-1" den Jahrgang
  /// „20-1", während das Backend auf das Datum zurückfiel.
  test('was keine reine Ziffernfolge ist, fällt auf das Datum zurück', () {
    for (final jahr in ['-1', '+1', '٢٦', '2o']) {
      expect(
        VorgangJahrgang.fuer(
          vorgang(jahr: jahr, angefragtAm: DateTime(2024, 3, 7)),
        ),
        '2024',
        reason: '„$jahr" ist keine Jahreszahl',
      );
    }
  });
}
