import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_group.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Kennzeichen gehen so weiter, **wie sie eingegeben wurden** (§4.2, geändert
/// am 11.09.2026): in die Referenz und in die Daten des Vorgangs. Bis dahin
/// schrieb die App sie in die Schreibweise mit Bindestrich um.
///
/// Dass das Feld selbst nichts umschreibt, hält `kennzeichen_field_test.dart`
/// fest; hier geht es um das, was aus dem Formular gelesen wird.
void main() {
  FormGroup formularMit({String gegner = '', String mandant = ''}) =>
      createVorgangForm()
        ..control('auftragsnummer').value = '84'
        ..control('auftragsjahr').value = '26'
        ..control('abteilung').value = 'C03'
        ..control('kennzeichenGegner').value = gegner
        ..control('mandantKennzeichen').value = mandant;

  const eingaben = ['hg-e1427', 'HGE1427', 'HG E 1427', '123 ABC'];

  test('die Referenz übernimmt das Kennzeichen, wie es eingegeben wurde', () {
    for (final kennzeichen in eingaben) {
      expect(
        baueReferenz(
          formularMit(gegner: kennzeichen),
          RechtsgebietWert.verkehrsrecht,
        ),
        '84/26 C03_$kennzeichen',
        reason: kennzeichen,
      );
    }
  });

  test('die Vorgangsdaten übernehmen beide Kennzeichen ebenso', () {
    for (final kennzeichen in eingaben) {
      final daten = leseVorgangDaten(
        formularMit(gegner: kennzeichen, mandant: kennzeichen),
        RechtsgebietWert.verkehrsrecht,
      );

      expect(daten.kennzeichenGegner, kennzeichen, reason: kennzeichen);
      expect(daten.mandantKennzeichen, kennzeichen, reason: kennzeichen);
    }
  });

  /// Kein Stück Schreibweise, sondern Zuordnung: Der Parser liest „Ihr
  /// Zeichen" mit zusammengezogenem Leerraum zurück.
  test('nur der Leerraum wird vereinheitlicht', () {
    expect(
      baueReferenz(
        formularMit(gegner: '  HG   E 1427 '),
        RechtsgebietWert.verkehrsrecht,
      ),
      '84/26 C03_HG E 1427',
    );
  });
}
