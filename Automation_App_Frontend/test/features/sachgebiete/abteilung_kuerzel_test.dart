import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Regeln aus §7.1: Zusammensetzung und Rückabbildung von Überschneidungen
/// (`C05/3`) und die Normalisierung der Kürzel. Die Beispiele sind die des
/// Anforderungsdokuments — wer die Regel dort ändert, fällt hier durch.
void main() {
  group('setzeZusammen', () {
    test('ohne Nebensachgebiet bleibt das Hauptkürzel', () {
      expect(AbteilungKuerzel.setzeZusammen('C03', null), 'C03');
      expect(AbteilungKuerzel.setzeZusammen('C03', ''), 'C03');
    });

    test('mit Nebensachgebiet entsteht die Schreibweise der Kanzlei', () {
      expect(AbteilungKuerzel.setzeZusammen('C05', 'C03'), 'C05/3');
      expect(AbteilungKuerzel.setzeZusammen('C05', 'C03o'), 'C05/3o');
      expect(AbteilungKuerzel.setzeZusammen('C05', 'C01a'), 'C05/1a');
    });
  });

  group('zerlege', () {
    test('ohne Schrägstrich ist alles Hauptkürzel', () {
      expect(AbteilungKuerzel.zerlege('C03o'), (haupt: 'C03o', neben: null));
    });

    test('bildet den Nebenteil auf sein Kürzel zurück', () {
      expect(AbteilungKuerzel.zerlege('C05/3'), (haupt: 'C05', neben: 'C03'));
      expect(AbteilungKuerzel.zerlege('C05/3o'), (haupt: 'C05', neben: 'C03o'));
    });

    test('ist die Umkehrung von setzeZusammen', () {
      for (final (haupt, neben) in [
        ('C03', null),
        ('C05', 'C03'),
        ('C05', 'C03o'),
        ('C01', 'C01a'),
      ]) {
        final abteilung = AbteilungKuerzel.setzeZusammen(haupt, neben);
        expect(AbteilungKuerzel.zerlege(abteilung), (
          haupt: haupt,
          neben: neben,
        ));
      }
    });
  });

  group('normalisiere', () {
    /// Die Referenz-Zerlegung trennt die Abteilung am Leerzeichen (§4.2) —
    /// ein Kürzel wie `C 03o` zerfiele dort auf beiden Seiten still.
    test('entfernt Leerzeichen aus dem Bestand', () {
      expect(AbteilungKuerzel.normalisiere('C 03o'), 'C03o');
      expect(AbteilungKuerzel.normalisiere(' C05 / 3 '), 'C05/3');
      expect(AbteilungKuerzel.normalisiere(null), '');
    });
  });
}
