import 'package:automation_app/features/dashboard/domain/services/dashboard_uebersicht.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final jetzt = DateTime(2026, 8, 2);

  Vorgang vorgang(
    String referenz, {
    required VorgangStatus status,
    int tageAlt = 0,
    int? laufendeNummer,
    DateTime? abgeschlossenAm,
  }) {
    return Vorgang(
      referenz: referenz,
      angefragtAm: jetzt.subtract(Duration(days: tageAlt)),
      status: status,
      laufendeNummer: laufendeNummer,
      abgeschlossenAm: abgeschlossenAm,
    );
  }

  List<String> referenzen(List<Vorgang> vorgaenge) =>
      vorgaenge.map((v) => v.referenz).toList();

  group('offene Vorgänge', () {
    test('sortiert nach Handlungsbedarf, innerhalb dessen ältester zuerst', () {
      final uebersicht = DashboardUebersicht.aus(
        [
          vorgang('frisch', status: VorgangStatus.angefragt, tageAlt: 1),
          vorgang('abgelegt', status: VorgangStatus.abgelegt, tageAlt: 3),
          vorgang('wartet-lange', status: VorgangStatus.angefragt, tageAlt: 20),
          vorgang('beantwortet', status: VorgangStatus.beantwortet, tageAlt: 2),
          vorgang('erstellt-alt', status: VorgangStatus.erstellt, tageAlt: 9),
        ],
        jetzt: jetzt,
      );

      expect(referenzen(uebersicht.offeneVorgaenge), [
        'beantwortet',
        'erstellt-alt',
        'abgelegt',
        'wartet-lange',
        'frisch',
      ]);
    });

    test('versendete Vorgänge zählen nicht als offen', () {
      final uebersicht = DashboardUebersicht.aus(
        [
          vorgang('offen', status: VorgangStatus.beantwortet),
          vorgang('fertig', status: VorgangStatus.versendet, laufendeNummer: 1),
        ],
        jetzt: jetzt,
      );

      expect(referenzen(uebersicht.offeneVorgaenge), ['offen']);
      expect(uebersicht.anzahlOffen, 1);
    });

    test('kürzt die Liste, meldet aber die volle Anzahl', () {
      final uebersicht = DashboardUebersicht.aus(
        [
          for (var i = 0; i < 9; i++)
            vorgang('v$i', status: VorgangStatus.angefragt, tageAlt: i),
        ],
        jetzt: jetzt,
        maxOffene: 4,
      );

      expect(uebersicht.offeneVorgaenge, hasLength(4));
      expect(uebersicht.anzahlOffen, 9);
    });
  });

  group('Registerausschnitt', () {
    test('liefert die zuletzt vergebenen Nummern in Registerreihenfolge', () {
      final uebersicht = DashboardUebersicht.aus(
        [
          for (var nr = 1; nr <= 12; nr++)
            vorgang(
              'nr-$nr',
              status: VorgangStatus.versendet,
              laufendeNummer: nr,
            ),
          vorgang('offen', status: VorgangStatus.angefragt),
        ],
        jetzt: jetzt,
        maxRegister: 5,
      );

      expect(uebersicht.registerGesamt, 12);
      expect(
        uebersicht.registerZeilen.map((v) => v.laufendeNummer).toList(),
        [8, 9, 10, 11, 12],
      );
    });

    test('Vorgänge ohne laufende Nummer verdrängen den Ausschnitt nicht', () {
      final uebersicht = DashboardUebersicht.aus(
        [
          vorgang('ohne-nummer', status: VorgangStatus.versendet),
          vorgang('nr-1', status: VorgangStatus.versendet, laufendeNummer: 1),
          vorgang('nr-2', status: VorgangStatus.versendet, laufendeNummer: 2),
        ],
        jetzt: jetzt,
        maxRegister: 2,
      );

      expect(referenzen(uebersicht.registerZeilen), ['nr-1', 'nr-2']);
    });

    test('gleiche Nummer: der zuletzt abgeschlossene Vorgang steht hinten', () {
      final uebersicht = DashboardUebersicht.aus(
        [
          vorgang(
            'spaeter',
            status: VorgangStatus.versendet,
            laufendeNummer: 3,
            abgeschlossenAm: DateTime(2026, 7, 30),
          ),
          vorgang(
            'frueher',
            status: VorgangStatus.versendet,
            laufendeNummer: 3,
            abgeschlossenAm: DateTime(2026, 7, 1),
          ),
        ],
        jetzt: jetzt,
      );

      expect(referenzen(uebersicht.registerZeilen), ['frueher', 'spaeter']);
    });
  });
}
