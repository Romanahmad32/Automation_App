import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/offene_anfrage.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vorgang.ausAnfrage', () {
    test('zerlegt die Referenz in ihre Bestandteile', () {
      final vorgang = Vorgang.ausAnfrage(
        referenz: '84/26 C03_GG-CK 321',
        angefragtAm: DateTime(2026, 6, 20),
      );

      expect(vorgang.laufendeNummer, 84);
      expect(vorgang.jahr, '26');
      expect(vorgang.abteilung, 'C03');
      expect(vorgang.kennzeichen, 'GG-CK 321');
      expect(vorgang.status, VorgangStatus.angefragt);
      expect(vorgang.rechtsgebiet, Rechtsgebiet.verkehrsrecht);
      expect(vorgang.aktenzeichen, '84/26 C03');
    });

    test('lässt Bestandteile leer, wenn die Referenz dem Schema nicht folgt',
        () {
      final vorgang = Vorgang.ausAnfrage(
        referenz: 'freitext-referenz',
        angefragtAm: DateTime(2026, 6, 20),
      );

      expect(vorgang.laufendeNummer, isNull);
      expect(vorgang.aktenzeichen, 'freitext-referenz');
    });
  });

  test('toJson/fromJson ist verlustfrei (inkl. Antwortdaten)', () {
    final original = Vorgang.ausAnfrage(
      referenz: '12/26 C03_HG-E 1427',
      angefragtAm: DateTime(2026, 6, 1),
      mandantId: 7,
      mandantName: 'Max Müller',
    ).mitAntwort(
      const ZentralrufReplyData(
        referenz: '12/26 C03_HG-E 1427',
        versichererName: 'HUK',
        unfallDatum: '20.06.2026',
        kennzeichen: 'HG-E 1427',
      ),
    );

    final kopie = Vorgang.fromJson(original.toJson());

    expect(kopie, original);
    expect(kopie.status, VorgangStatus.beantwortet);
    expect(kopie.antwort?.versichererName, 'HUK');
    expect(kopie.parteienBezeichnung, 'Max Müller ./. HUK');
  });

  test('fromJson fällt bei unbekanntem Rechtsgebiet/Status tolerant zurück', () {
    final vorgang = Vorgang.fromJson({
      'referenz': '1/26 C03_HG-E 1',
      'angefragtAm': DateTime(2026, 1, 1).toIso8601String(),
      'rechtsgebiet': 'voelkerrecht',
      'status': 'archiviert',
    });

    expect(vorgang.rechtsgebiet, Rechtsgebiet.verkehrsrecht);
    expect(vorgang.status, VorgangStatus.angefragt);
  });

  group('migriereAusLegacy', () {
    test('macht aus offenen Anfragen angefragte Vorgänge', () {
      final vorgaenge = Vorgang.migriereAusLegacy(
        offeneAnfragen: [
          OffeneAnfrage(
            referenz: '84/26 C03_GG-CK 321',
            angefragtAm: DateTime(2026, 6, 20),
          ),
        ],
        letzteAntwort: null,
      );

      expect(vorgaenge, hasLength(1));
      expect(vorgaenge.single.status, VorgangStatus.angefragt);
      expect(vorgaenge.single.laufendeNummer, 84);
    });

    test('hängt die letzte Antwort an den Vorgang mit passender Referenz', () {
      final vorgaenge = Vorgang.migriereAusLegacy(
        offeneAnfragen: [
          OffeneAnfrage(
            referenz: '84/26 C03_GG-CK 321',
            angefragtAm: DateTime(2026, 6, 20),
          ),
        ],
        letzteAntwort: const ZentralrufReplyData(
          referenz: '84/26  c03_gg-ck 321',
          versichererName: 'HUK',
        ),
      );

      expect(vorgaenge, hasLength(1));
      expect(vorgaenge.single.status, VorgangStatus.beantwortet);
      expect(vorgaenge.single.gegner, 'HUK');
    });

    test('ergänzt einen eigenen Vorgang, wenn keine Anfrage passt', () {
      final vorgaenge = Vorgang.migriereAusLegacy(
        offeneAnfragen: const [],
        letzteAntwort: const ZentralrufReplyData(
          referenz: '99/26 C03_AB-CD 1',
          versichererName: 'Allianz',
        ),
      );

      expect(vorgaenge, hasLength(1));
      expect(vorgaenge.single.referenz, '99/26 C03_AB-CD 1');
      expect(vorgaenge.single.status, VorgangStatus.beantwortet);
    });
  });
}
