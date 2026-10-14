import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_fehler_art.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_fortschritt.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aktualisierung_doubles.dart';

void main() {
  group('updateInSicht', () {
    test('verfügbar, lädt, bereit und Fehler zeigen den Hinweis', () {
      for (final zustand in [
        AktualisierungsZustand.verfuegbar,
        AktualisierungsZustand.laedt,
        AktualisierungsZustand.bereit,
        AktualisierungsZustand.fehler,
      ]) {
        expect(standMit(zustand).updateInSicht, isTrue, reason: '$zustand');
      }
    });

    test('unbekannt, aktuell oder ohne neue Version nicht', () {
      expect(standMit(AktualisierungsZustand.unbekannt).updateInSicht, isFalse);
      expect(standMit(AktualisierungsZustand.aktuell).updateInSicht, isFalse);
      expect(
        standMit(
          AktualisierungsZustand.fehler,
          neueVersion: null,
        ).updateInSicht,
        isFalse,
      );
    });
  });

  test('Prozent sind abgerundet, ohne Größe gibt es keine', () {
    const mib = 1024 * 1024;
    expect(
      standMit(AktualisierungsZustand.laedt, geladen: 54 * mib).prozent,
      58,
    );
    expect(
      standMit(
        AktualisierungsZustand.laedt,
        geladen: 54 * mib,
        gesamt: null,
      ).prozent,
      isNull,
    );
  });

  group('Ursache im Fehlerfall (2d) aus fehlerArt', () {
    test('abgerissene oder stockende Verbindung', () {
      expect(
        AktualisierungsFehlerArt.ausText('verbindung'),
        AktualisierungsFehlerArt.verbindung,
      );
    });

    test('Größe oder Prüfsumme falsch', () {
      expect(
        AktualisierungsFehlerArt.ausText('pruefung'),
        AktualisierungsFehlerArt.pruefung,
      );
    });

    test('alles andere behält den Satz des Dienstes', () {
      expect(
        AktualisierungsFehlerArt.ausText('sonstig'),
        AktualisierungsFehlerArt.sonstig,
      );
    });

    test('ein unbekannter Wert gilt als sonstig, kein Wert als keiner', () {
      expect(
        AktualisierungsFehlerArt.ausText('neu-erfunden'),
        AktualisierungsFehlerArt.sonstig,
        reason: 'Ein neuerer Dienst bekommt nie eine falsche Ursache.',
      );
      expect(AktualisierungsFehlerArt.ausText(null), isNull);
    });

    test('der Wortlaut der Meldung bestimmt die Ursache nicht mehr', () {
      final stand = AktualisierungsStand.fromJson(const {
        'laufendeVersion': '1.3.0',
        'neueVersion': '1.4.0',
        'zustand': 'fehler',
        'meldung':
            'Der Download wurde unterbrochen — vermutlich ist die '
            'Internetverbindung abgerissen.',
        'fehlerArt': 'pruefung',
      });

      expect(stand.fehlerArt, AktualisierungsFehlerArt.pruefung);
    });
  });

  test('Mengenangabe im Dialog: ganze MB, darunter eine Nachkommastelle', () {
    const mib = 1024 * 1024;
    expect(
      AktualisierungsFortschritt.mengenText(54 * mib, 92 * mib),
      '54 von 92 MB',
    );
    expect(
      AktualisierungsFortschritt.mengenText(mib ~/ 2, mib),
      '0,5 von 1,0 MB',
    );
  });
}
