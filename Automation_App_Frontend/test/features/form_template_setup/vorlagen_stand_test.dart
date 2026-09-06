import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Stand einer Vorlage (#104): eine Rechnung über **beide** Word-Dateien,
/// beide Richtungen zusammen — Platzhalter ohne Feld (Mangel) und Feld ohne
/// Platzhalter (Warnung).
void main() {
  VorlagenStand stand({
    bool hatDateiOhne = true,
    bool hatDateiMit = true,
    List<String>? platzhalterOhne = const [],
    List<String>? platzhalterMit = const [],
    Iterable<String?> feldnamen = const [],
  }) => VorlagenStand.bestimme(
    hatDateiOhne: hatDateiOhne,
    hatDateiMit: hatDateiMit,
    platzhalterOhne: platzhalterOhne,
    platzhalterMit: platzhalterMit,
    feldnamen: feldnamen,
  );

  group('Platzhalter ohne Feld — eine Rechnung über beide Dateien', () {
    test('zählt einen Platzhalter aus beiden Dateien nur einmal und hält die '
        'Dokumentreihenfolge (erst ohne, dann mit Auflistung)', () {
      final ergebnis = stand(
        platzhalterOhne: const ['Kennzeichen', 'Frist'],
        platzhalterMit: const ['Kennzeichen', 'Schadenshoehe'],
      );

      expect(ergebnis.platzhalterOhneFeld, [
        'Kennzeichen',
        'Frist',
        'Schadenshoehe',
      ]);
      expect(ergebnis.istVollstaendig, isFalse);
    });

    test('app-eigene Platzhalter sind nie offen', () {
      final ergebnis = stand(
        platzhalterOhne: const ['Gegenstandswert', 'RvgBrutto'],
        platzhalterMit: const ['Schadensaufstellung', 'RvgNetto'],
      );

      expect(ergebnis.platzhalterOhneFeld, isEmpty);
      expect(ergebnis.istVollstaendig, isTrue);
      expect(ergebnis.zusammenfassung, 'Vollständig');
    });

    test('ein zugeordneter Platzhalter ist kein Mangel — ohne '
        'Groß-/Kleinschreibung und Randleerzeichen', () {
      final ergebnis = stand(
        platzhalterOhne: const ['Kennzeichen'],
        platzhalterMit: const ['kennzeichen'],
        feldnamen: const [' KENNZEICHEN '],
      );

      expect(ergebnis.platzhalterOhneFeld, isEmpty);
      expect(ergebnis.felderOhneVorkommen, isEmpty);
      expect(ergebnis.istVollstaendig, isTrue);
    });
  });

  group('Felder ohne Vorkommen sind nur eine Warnung', () {
    test('machen die Vorlage nicht unvollständig', () {
      final ergebnis = stand(
        platzhalterOhne: const ['Kennzeichen'],
        platzhalterMit: const ['Kennzeichen'],
        feldnamen: const ['Kennzeichen', 'Vertipptt'],
      );

      expect(ergebnis.felderOhneVorkommen, ['Vertipptt']);
      expect(ergebnis.hatWarnungen, isTrue);
      expect(ergebnis.istVollstaendig, isTrue);
      expect(ergebnis.mangelText, isNull);
      expect(
        ergebnis.zusammenfassung,
        'Vollständig · 1 Feld in keiner Datei (Warnung)',
      );
    });

    test('ein Feld, das nur in einer der beiden Dateien steht, ist keine '
        'Warnung', () {
      final ergebnis = stand(
        platzhalterOhne: const ['Frist'],
        platzhalterMit: const ['Schadenshoehe'],
        feldnamen: const ['Frist', 'Schadenshoehe'],
      );

      expect(ergebnis.felderOhneVorkommen, isEmpty);
      expect(ergebnis.hatWarnungen, isFalse);
    });

    test('melden jeden Namen einmal, in Feldreihenfolge, ohne '
        'Randleerzeichen', () {
      final ergebnis = stand(
        platzhalterOhne: const ['Kennzeichen'],
        platzhalterMit: const [],
        feldnamen: const ['Zweitname', '  Frist ', 'frist', 'Kennzeichen'],
      );

      expect(ergebnis.felderOhneVorkommen, ['Zweitname', 'Frist']);
    });

    test('leere und fehlende Feldnamen sind kein Mangel', () {
      final ergebnis = stand(
        platzhalterOhne: const ['Kennzeichen'],
        platzhalterMit: const ['Kennzeichen'],
        feldnamen: const [null, '', '   ', 'Kennzeichen'],
      );

      expect(ergebnis.felderOhneVorkommen, isEmpty);
      expect(ergebnis.anzahlOffen, 0);
    });
  });

  group('Welche Dateien es gibt', () {
    test('keine Datei — unvollständig; die Felder werden nicht angemahnt, es '
        'gibt nichts, wogegen sie fehlen könnten', () {
      final ergebnis = stand(
        hatDateiOhne: false,
        hatDateiMit: false,
        platzhalterOhne: null,
        platzhalterMit: null,
        feldnamen: const ['Kennzeichen'],
      );

      expect(ergebnis.hatDatei, isFalse);
      expect(ergebnis.istVollstaendig, isFalse);
      expect(ergebnis.platzhalterUnbekannt, isFalse);
      expect(ergebnis.felderOhneVorkommen, isEmpty);
      expect(ergebnis.zusammenfassung, 'Keine Word-Datei verknüpft');
    });

    test('nur die Datei ohne Auflistung, alles zugeordnet — vollständig', () {
      final ergebnis = stand(
        hatDateiMit: false,
        platzhalterOhne: const ['Kennzeichen'],
        platzhalterMit: null,
        feldnamen: const ['Kennzeichen'],
      );

      expect(ergebnis.hatDatei, isTrue);
      expect(ergebnis.istVollstaendig, isTrue);
      expect(ergebnis.hatWarnungen, isFalse);
      expect(ergebnis.platzhalterUnbekannt, isFalse);
    });

    test('nur die Datei mit Auflistung, alles zugeordnet — vollständig; '
        'die beiden Dateien sind gleichwertig', () {
      final ergebnis = stand(
        hatDateiOhne: false,
        platzhalterOhne: null,
        platzhalterMit: const ['Schadenshoehe'],
        feldnamen: const ['Schadenshoehe'],
      );

      expect(ergebnis.hatDatei, isTrue);
      expect(ergebnis.istVollstaendig, isTrue);
      expect(ergebnis.zusammenfassung, 'Vollständig');
    });
  });

  group('Platzhalterliste einer vorhandenen Datei unbekannt', () {
    test('meldet die Unsicherheit und keine Felder ohne Vorkommen', () {
      final ergebnis = stand(
        platzhalterOhne: null,
        platzhalterMit: const ['Kennzeichen'],
        feldnamen: const ['Kennzeichen', 'Frist'],
      );

      expect(ergebnis.platzhalterUnbekannt, isTrue);
      // „Frist" könnte in der ungelesenen Datei stehen — nichts anmahnen.
      expect(ergebnis.felderOhneVorkommen, isEmpty);
      expect(ergebnis.hatWarnungen, isFalse);
    });

    test('zählt die offenen Platzhalter nur aus den bekannten Listen', () {
      final ergebnis = stand(
        platzhalterOhne: null,
        platzhalterMit: const ['Schadenshoehe'],
      );

      expect(ergebnis.platzhalterOhneFeld, ['Schadenshoehe']);
      expect(
        ergebnis.zusammenfassung,
        '1 Platzhalter ohne Feld · Platzhalter noch nicht gelesen',
      );
    });

    test('bleibt ohne Vorbehalt, wenn nur die fehlende Datei keine Liste '
        'hat', () {
      final ergebnis = stand(
        hatDateiMit: false,
        platzhalterOhne: const ['Kennzeichen'],
        platzhalterMit: null,
      );

      expect(ergebnis.platzhalterUnbekannt, isFalse);
      expect(ergebnis.unbekanntText, isNull);
    });
  });

  group('Zusammenfassung und Bestandteile', () {
    test('anzahlOffen zählt beide Richtungen zusammen', () {
      final ergebnis = stand(
        platzhalterOhne: const ['Kennzeichen', 'Frist'],
        platzhalterMit: const ['Kennzeichen', 'Schadenshoehe'],
        feldnamen: const ['Vertipptt', 'Zweitname'],
      );

      expect(ergebnis.platzhalterOhneFeld, hasLength(3));
      expect(ergebnis.felderOhneVorkommen, hasLength(2));
      expect(ergebnis.anzahlOffen, 5);
    });

    test('mangelText ist genau dann gesetzt, wenn die Vorlage unvollständig '
        'ist — und zählt Einzahl wie Mehrzahl', () {
      final fertig = stand(
        platzhalterOhne: const ['Frist'],
        feldnamen: const ['Frist'],
      );

      expect(fertig.istVollstaendig, isTrue);
      expect(fertig.mangelText, isNull);
      expect(
        stand(platzhalterOhne: const ['Frist']).mangelText,
        '1 Platzhalter ohne Feld',
      );
      expect(
        stand(platzhalterOhne: const ['Frist', 'Kennzeichen']).mangelText,
        '2 Platzhalter ohne Feld',
      );
    });

    test('zählt im Warnungstext Einzahl und Mehrzahl', () {
      expect(
        stand(
          platzhalterOhne: const ['Kennzeichen'],
          feldnamen: const ['Kennzeichen', 'Eins'],
        ).warnungText,
        '1 Feld in keiner Datei (Warnung)',
      );
      expect(
        stand(
          platzhalterOhne: const ['Kennzeichen'],
          feldnamen: const ['Kennzeichen', 'Eins', 'Zwei'],
        ).warnungText,
        '2 Felder in keiner Datei (Warnung)',
      );
    });

    test('reiht Mangel, Warnung und Vorbehalt hintereinander', () {
      // Vorbehalt gesetzt: die Warnung entfällt, obwohl „Vertipptt" nirgends
      // vorkommt — deshalb hier nur Mangel und Vorbehalt.
      expect(
        stand(
          platzhalterOhne: const ['Frist', 'Kennzeichen'],
          platzhalterMit: null,
          feldnamen: const ['Vertipptt'],
        ).zusammenfassung,
        '2 Platzhalter ohne Feld · Platzhalter noch nicht gelesen',
      );
      expect(
        stand(
          platzhalterOhne: const ['Frist', 'Kennzeichen'],
          feldnamen: const ['Vertipptt'],
        ).zusammenfassung,
        '2 Platzhalter ohne Feld · 1 Feld in keiner Datei (Warnung)',
      );
    });
  });
}
