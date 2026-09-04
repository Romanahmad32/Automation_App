import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Vorbelegung eines Datumsfelds (§5.3): Kalenderrechnung, Rundlauf durch
/// JSON und die Namensregel als Rückfall.
///
/// Die Überlauffälle stehen hier namentlich, weil sie die Entscheidung
/// festhalten, mit dem [DateTime]-Konstruktor statt mit `Duration` zu rechnen
/// — „31.01. + 1 Monat" ist ohne diese Tests eine Meinung.
void main() {
  group('anwendenAuf', () {
    test('5 Wochen sind 35 Tage', () {
      const vorbelegung = DatumsVorbelegung(wochen: 5);

      expect(
        vorbelegung.anwendenAuf(DateTime(2026, 9, 3)),
        DateTime(2026, 10, 8),
      );
    });

    test('1 Jahr und 4 Tage', () {
      const vorbelegung = DatumsVorbelegung(jahre: 1, tage: 4);

      expect(
        vorbelegung.anwendenAuf(DateTime(2026, 9, 3)),
        DateTime(2027, 9, 7),
      );
    });

    test('1 Jahr, 2 Wochen und 9 Tage', () {
      const vorbelegung = DatumsVorbelegung(jahre: 1, wochen: 2, tage: 9);

      // 03.09.2027 + 14 + 9 Tage = 26.09.2027
      expect(
        vorbelegung.anwendenAuf(DateTime(2026, 9, 3)),
        DateTime(2027, 9, 26),
      );
    });

    test('29.02.2028 + 1 Jahr landet auf dem 01.03.2029', () {
      // 2029 hat keinen 29. Februar — der Konstruktor normalisiert.
      expect(
        const DatumsVorbelegung(jahre: 1).anwendenAuf(DateTime(2028, 2, 29)),
        DateTime(2029, 3, 1),
      );
    });

    test('31.01.2027 + 1 Monat landet auf dem 03.03.2027', () {
      // Februar 2027 hat 28 Tage.
      expect(
        const DatumsVorbelegung(monate: 1).anwendenAuf(DateTime(2027, 1, 31)),
        DateTime(2027, 3, 3),
      );
    });

    test('31.01.2028 + 1 Monat landet im Schaltjahr auf dem 02.03.2028', () {
      // Februar 2028 hat 29 Tage — ein Tag früher als im Vorjahr.
      expect(
        const DatumsVorbelegung(monate: 1).anwendenAuf(DateTime(2028, 1, 31)),
        DateTime(2028, 3, 2),
      );
    });

    test('ohne Verschiebung bleibt die Basis unverändert', () {
      const vorbelegung = DatumsVorbelegung();

      expect(vorbelegung.istHeute, isTrue);
      expect(
        vorbelegung.anwendenAuf(DateTime(2026, 9, 3)),
        DateTime(2026, 9, 3),
      );
    });
  });

  group('JSON', () {
    test('Rundlauf erhält alle vier Werte', () {
      const vorbelegung = DatumsVorbelegung(
        jahre: 1,
        monate: 2,
        wochen: 3,
        tage: 4,
      );

      expect(
        DatumsVorbelegung.fromJson(vorbelegung.toJson()),
        vorbelegung,
        reason: 'Equatable vergleicht die Werte, nicht die Identität',
      );
    });

    test('toJson schreibt alle vier Schlüssel', () {
      expect(const DatumsVorbelegung(wochen: 5).toJson(), {
        'jahre': 0,
        'monate': 0,
        'wochen': 5,
        'tage': 0,
      });
    });

    test('fehlende Schlüssel gelten als 0', () {
      // Eine Vorlage, die nur `wochen` gespeichert hat, soll laden statt zu
      // werfen — sonst wäre jede Formatergänzung ein Datenverlust.
      final vorbelegung = DatumsVorbelegung.fromJson({'wochen': 2});

      expect(vorbelegung, const DatumsVorbelegung(wochen: 2));
    });

    test('ein leeres Objekt ergibt „heute"', () {
      expect(DatumsVorbelegung.fromJson({}), const DatumsVorbelegung());
    });
  });

  group('ausFeldname', () {
    test('„Zahlungsfrist" bekommt 5 Wochen', () {
      expect(
        DatumsVorbelegung.ausFeldname('Zahlungsfrist'),
        const DatumsVorbelegung(wochen: 5),
      );
    });

    test('„Zahlungs-Frist" und „ZAHLUNGSFRIST" ebenso', () {
      // Normalisiert wird über FeldDatenquelleErkennung — Bindestrich und
      // Großschreibung meinen denselben Namen.
      expect(
        DatumsVorbelegung.ausFeldname('Zahlungs-Frist'),
        const DatumsVorbelegung(wochen: 5),
      );
      expect(
        DatumsVorbelegung.ausFeldname('ZAHLUNGSFRIST'),
        const DatumsVorbelegung(wochen: 5),
      );
    });

    test('„Frist" bekommt 4 Wochen', () {
      // Die Reihenfolge der Prüfungen ist die Regel: „frist" steckt in
      // „zahlungsfrist", deshalb wird der längere Name zuerst geprüft
      // (Entscheidung vom 29.08.2026).
      expect(
        DatumsVorbelegung.ausFeldname('Frist'),
        const DatumsVorbelegung(wochen: 4),
      );
    });

    test('„Unfalldatum" bekommt keine Verschiebung', () {
      expect(
        DatumsVorbelegung.ausFeldname('Unfalldatum'),
        const DatumsVorbelegung(),
      );
    });

    test('„Zahlungsfrist des Gegners" bekommt 5 Wochen', () {
      // Bekanntes Verhalten des Teilstring-Tests: Ein Zusatz hinter dem Namen
      // ändert nichts. Hier festgehalten, damit es nicht als Zufall gilt —
      // eine Verschärfung auf exakten Vergleich nähme jedem so benannten Feld
      // still seine Vorbelegung.
      expect(
        DatumsVorbelegung.ausFeldname('Zahlungsfrist des Gegners'),
        const DatumsVorbelegung(wochen: 5),
      );
    });
  });

  group('beschreibung', () {
    test('ohne Verschiebung „heute"', () {
      expect(const DatumsVorbelegung().beschreibung, 'heute');
    });

    test('ein Bestandteil ohne Aufzählung', () {
      expect(
        const DatumsVorbelegung(wochen: 5).beschreibung,
        'heute + 5 Wochen',
      );
    });

    test('mehrere Bestandteile mit „und" vor dem letzten', () {
      expect(
        const DatumsVorbelegung(jahre: 1, wochen: 2, tage: 9).beschreibung,
        'heute + 1 Jahr, 2 Wochen und 9 Tage',
      );
    });

    test('Einzahl bei genau 1', () {
      expect(
        const DatumsVorbelegung(monate: 1, tage: 1).beschreibung,
        'heute + 1 Monat und 1 Tag',
      );
    });
  });
}
