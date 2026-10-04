import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_vorbelegung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die vorbelegten Kopfzeilen der Vollmacht (§4.11) — und die Regel, dass
/// abgeleitete Zeilen nur folgen, solange der Anwalt sie nicht geändert hat.
void main() {
  final vorgang = Vorgang(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 8, 3),
    unfallDatum: '02.08.2026',
    mandantId: 7,
  );
  final mandant = Mandant(
    id: 7,
    vorname: 'Anna',
    nachname: 'Mustermann',
    strasseHausnummer: 'Musterweg 4',
    postleitzahl: '12345',
    ort: 'Musterstadt',
    telefonnummer: '0170 1234567',
    emailAdresse: 'anna@example.org',
    erstelltAm: DateTime(2026),
  );

  group('Vorbelegung je Art', () {
    test('Unfallsachen: wegen trägt das Unfalldatum, in Sachen leer', () {
      final kopf = VollmachtVorbelegung.fuer(
        vorgang: vorgang,
        mandant: mandant,
        art: VollmachtArt.unfallsachen,
      );
      expect(kopf.inSachen, '');
      expect(kopf.wegen, 'Schadensersatz nach Verkehrsunfall vom 02.08.2026');
      expect(kopf.strasse, 'Musterweg 4');
      expect(kopf.telefon, '0170 1234567');
    });

    test('Bußgeldsachen: Name in Sachen, Tatdatum bleibt offen', () {
      final kopf = VollmachtVorbelegung.fuer(
        vorgang: vorgang,
        mandant: mandant,
        art: VollmachtArt.bussgeldsachen,
      );
      expect(kopf.inSachen, 'Bußgeldsache Anna Mustermann');
      expect(kopf.wegen, 'Vorwurf der OWi. am ');
    });

    test('Strafsache: wegen nennt den Mandanten', () {
      final kopf = VollmachtVorbelegung.fuer(
        vorgang: vorgang,
        mandant: mandant,
        art: VollmachtArt.strafsache,
      );
      expect(kopf.inSachen, '');
      expect(kopf.wegen, 'Strafverfahren gegen Anna Mustermann');
    });

    test('ohne Art bleiben in Sachen und wegen leer', () {
      final kopf = VollmachtVorbelegung.fuer(
        vorgang: vorgang,
        mandant: mandant,
      );
      expect((kopf.inSachen, kopf.wegen), ('', ''));
    });
  });

  test('ohne Mandant bleiben die Mandantenfelder leer', () {
    final kopf = VollmachtVorbelegung.fuer(
      vorgang: vorgang,
      art: VollmachtArt.strafsache,
    );
    expect(kopf.name, '');
    expect(kopf.strasse, '');
    expect(kopf.wegen, 'Strafverfahren gegen');
  });

  group('nachziehen', () {
    final alt = VollmachtVorbelegung.fuer(
      vorgang: vorgang,
      mandant: mandant,
      art: VollmachtArt.strafsache,
    );

    test('ein korrigierter Name wandert in das unberührte wegen', () {
      final neu = VollmachtVorbelegung.nachziehen(
        altArt: VollmachtArt.strafsache,
        alt: alt,
        neuArt: VollmachtArt.strafsache,
        neu: alt.copyWith(vorname: 'Anne'),
      );
      expect(neu.wegen, 'Strafverfahren gegen Anne Mustermann');
    });

    test('ein von Hand geändertes wegen bleibt stehen', () {
      final eigen = alt.copyWith(wegen: 'Strafverfahren wegen Nötigung');
      final neu = VollmachtVorbelegung.nachziehen(
        altArt: VollmachtArt.strafsache,
        alt: eigen,
        neuArt: VollmachtArt.strafsache,
        neu: eigen.copyWith(vorname: 'Anne'),
      );
      expect(neu.wegen, 'Strafverfahren wegen Nötigung');
    });

    test('ein Wechsel der Art belegt die unberührten Zeilen neu', () {
      final neu = VollmachtVorbelegung.nachziehen(
        altArt: VollmachtArt.strafsache,
        alt: alt,
        neuArt: VollmachtArt.bussgeldsachen,
        neu: alt,
      );
      expect(neu.inSachen, 'Bußgeldsache Anna Mustermann');
      expect(neu.wegen, 'Vorwurf der OWi. am ');
    });
  });
}
