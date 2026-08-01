import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/antwort_konflikte.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Vorgang vorgang({String? gegner, String? unfallDatum}) => Vorgang(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 4, 8),
    gegner: gegner,
    unfallDatum: unfallDatum,
  );

  const antwort = ZentralrufReplyData(
    versichererName: 'HUK-COBURG',
    unfallDatum: '09.03.2026',
  );

  group('finde', () {
    test('meldet keine Konflikte, wenn Vorgangsfelder leer sind', () {
      expect(AntwortKonflikte.finde(vorgang(), antwort), isEmpty);
    });

    test('meldet keine Konflikte bei gleichen Werten (case-tolerant)', () {
      final konflikte = AntwortKonflikte.finde(
        vorgang(gegner: 'huk-coburg', unfallDatum: ' 09.03.2026 '),
        antwort,
      );
      expect(konflikte, isEmpty);
    });

    test('meldet abweichenden Gegner und abweichendes Unfalldatum', () {
      final konflikte = AntwortKonflikte.finde(
        vorgang(gegner: 'Allianz', unfallDatum: '08.03.2026'),
        antwort,
      );

      expect(konflikte, hasLength(2));
      expect(konflikte[0].feld, AntwortKonfliktFeld.gegner);
      expect(konflikte[0].erfassterWert, 'Allianz');
      expect(konflikte[0].antwortWert, 'HUK-COBURG');
      expect(konflikte[1].feld, AntwortKonfliktFeld.unfallDatum);
      expect(konflikte[1].erfassterWert, '08.03.2026');
      expect(konflikte[1].antwortWert, '09.03.2026');
    });

    test('meldet nichts, wenn die Antwort das Feld gar nicht hat', () {
      const leereAntwort = ZentralrufReplyData();
      final konflikte = AntwortKonflikte.finde(
        vorgang(gegner: 'Allianz', unfallDatum: '08.03.2026'),
        leereAntwort,
      );
      expect(konflikte, isEmpty);
    });
  });

  group('uebernehmen', () {
    final erfasst = vorgang(gegner: 'Allianz', unfallDatum: '08.03.2026');

    test('lässt ohne Entscheidungen die erfassten Werte stehen', () {
      final ergebnis = AntwortKonflikte.uebernehmen(erfasst, antwort);

      expect(ergebnis.gegner, 'Allianz');
      expect(ergebnis.unfallDatum, '08.03.2026');
      expect(ergebnis.antwort, antwort);
    });

    test('setzt für gewählte Felder den Antwortwert durch', () {
      final ergebnis = AntwortKonflikte.uebernehmen(
        erfasst,
        antwort,
        antwortGewinnt: {AntwortKonfliktFeld.unfallDatum},
      );

      expect(ergebnis.gegner, 'Allianz');
      expect(ergebnis.unfallDatum, '09.03.2026');
    });

    test('füllt leere Vorgangsfelder weiterhin aus der Antwort', () {
      final ergebnis = AntwortKonflikte.uebernehmen(vorgang(), antwort);

      expect(ergebnis.gegner, 'HUK-COBURG');
      expect(ergebnis.unfallDatum, '09.03.2026');
    });
  });
}
