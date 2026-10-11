import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:automation_app/features/vollmacht/domain/services/vollmacht_vorbelegung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die vorbelegten Kopfzeilen der Vollmacht (§4.11) — und die Regel, dass
/// abgeleitete Zeilen nur folgen, solange der Anwalt sie nicht geändert hat.
void main() {
  // Bewusst ausgeschrieben statt aus `VollmachtSchreiblinie`: Ändert jemand
  // die Länge, soll das hier auffallen — das Papier sieht dann anders aus.
  final datumsLinie = '_' * 12;
  final namensLinie = '_' * 32;

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

    test('Bußgeldsachen: Name in Sachen, Tatdatum als Linie', () {
      final kopf = VollmachtVorbelegung.fuer(
        vorgang: vorgang,
        mandant: mandant,
        art: VollmachtArt.bussgeldsachen,
      );
      expect(kopf.inSachen, 'Bußgeldsache Anna Mustermann');
      // #171: statt „am " mit nichts dahinter eine Linie für die Hand.
      expect(kopf.wegen, 'Vorwurf der OWi. am $datumsLinie');
      expect(kopf.tatdatum, '');
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
    // #171: Die Mandantenfelder gehen leer an den Dienst, der sie als Linie
    // druckt — „wegen" bekommt die Namenslinie schon hier.
    expect(kopf.wegen, 'Strafverfahren gegen $namensLinie');
  });

  group('Schreiblinie statt hängendem Zeilenende (#171)', () {
    test('Unfallsachen ohne Unfalldatum: Linie hinter „vom"', () {
      final kopf = VollmachtVorbelegung.fuer(
        vorgang: Vorgang(referenz: 'x', angefragtAm: DateTime(2026, 8, 3)),
        mandant: mandant,
        art: VollmachtArt.unfallsachen,
      );
      expect(kopf.wegen, 'Schadensersatz nach Verkehrsunfall vom $datumsLinie');
    });

    test('Bußgeldsachen ohne Mandant: Linie in „in Sachen"', () {
      final kopf = VollmachtVorbelegung.fuer(
        vorgang: vorgang,
        art: VollmachtArt.bussgeldsachen,
      );
      expect(kopf.inSachen, 'Bußgeldsache $namensLinie');
      expect(kopf.wegen, 'Vorwurf der OWi. am $datumsLinie');
    });

    test('ein halber Name ist ein Name — keine Linie für den Rest', () {
      final kopf = VollmachtVorbelegung.fuer(
        vorgang: vorgang,
        art: VollmachtArt.strafsache,
      ).copyWith(nachname: 'Mustermann');
      expect(
        VollmachtVorbelegung.wegen(VollmachtArt.strafsache, kopf),
        'Strafverfahren gegen Mustermann',
      );
    });

    test('das Tatdatum steht in „wegen", sobald es eingetragen ist', () {
      const kopf = VollmachtKopfdaten(tatdatum: ' 03.10.2026 ');
      expect(
        VollmachtVorbelegung.wegen(VollmachtArt.bussgeldsachen, kopf),
        'Vorwurf der OWi. am 03.10.2026',
      );
    });
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
      expect(neu.wegen, 'Vorwurf der OWi. am $datumsLinie');
    });
  });

  group('nachziehen mit Schreiblinie (#171)', () {
    final bussgeld = VollmachtVorbelegung.fuer(
      vorgang: vorgang,
      mandant: mandant,
      art: VollmachtArt.bussgeldsachen,
    );

    VollmachtKopfdaten zieheNach(
      VollmachtKopfdaten alt,
      VollmachtKopfdaten neu,
    ) => VollmachtVorbelegung.nachziehen(
      altArt: VollmachtArt.bussgeldsachen,
      alt: alt,
      neuArt: VollmachtArt.bussgeldsachen,
      neu: neu,
    );

    test('das Tatdatum ersetzt die Linie in „wegen" — und geht wieder', () {
      final mitDatum = zieheNach(
        bussgeld,
        bussgeld.copyWith(tatdatum: '03.10.2026'),
      );
      expect(mitDatum.wegen, 'Vorwurf der OWi. am 03.10.2026');

      final ohneDatum = zieheNach(mitDatum, mitDatum.copyWith(tatdatum: ''));
      expect(ohneDatum.wegen, 'Vorwurf der OWi. am $datumsLinie');
    });

    test('wer das Datum direkt über die Linie tippt, hat „wegen" geändert', () {
      final eigen = bussgeld.copyWith(wegen: 'Vorwurf der OWi. am 03.10.2026');
      final neu = zieheNach(
        eigen,
        eigen.copyWith(tatdatum: '04.10.2026', vorname: 'Anne'),
      );
      expect(neu.wegen, 'Vorwurf der OWi. am 03.10.2026');
      expect(neu.inSachen, 'Bußgeldsache Anne Mustermann');
    });

    test('ein nachgetragener Name ersetzt die Namenslinie', () {
      final ohneMandant = VollmachtVorbelegung.fuer(
        vorgang: vorgang,
        art: VollmachtArt.bussgeldsachen,
      );
      final neu = zieheNach(
        ohneMandant,
        ohneMandant.copyWith(vorname: 'Anna', nachname: 'Mustermann'),
      );
      expect(neu.inSachen, 'Bußgeldsache Anna Mustermann');
    });

    test('das Unfalldatum ersetzt die Linie hinter „vom"', () {
      final ohneDatum = VollmachtVorbelegung.fuer(
        vorgang: Vorgang(referenz: 'x', angefragtAm: DateTime(2026, 8, 3)),
        mandant: mandant,
        art: VollmachtArt.unfallsachen,
      );
      final neu = VollmachtVorbelegung.nachziehen(
        altArt: VollmachtArt.unfallsachen,
        alt: ohneDatum,
        neuArt: VollmachtArt.unfallsachen,
        neu: ohneDatum.copyWith(unfalldatum: '02.08.2026'),
      );
      expect(neu.wegen, 'Schadensersatz nach Verkehrsunfall vom 02.08.2026');
    });
  });
}
