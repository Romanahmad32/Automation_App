import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/presentation/utils/posteingang_tagesgruppen.dart';
import 'package:flutter_test/flutter_test.dart';

PosteingangEintrag _mail(String id, DateTime? datum) =>
    PosteingangEintrag(id: id, betreff: id, absender: 'Absender', datum: datum);

void main() {
  group('gruppierePosteingangNachTag', () {
    test(
      'fasst Zeilen desselben Kalendertags zusammen, ohne die Reihenfolge zu '
      'verändern',
      () {
        final a = _mail('a', DateTime(2026, 9, 13, 9));
        final b = _mail('b', DateTime(2026, 9, 13, 18, 30));
        final c = _mail('c', DateTime(2026, 9, 12, 8));
        final gruppen = gruppierePosteingangNachTag([a, b, c]);

        expect(gruppen, hasLength(2));
        expect(gruppen[0].tag, DateTime(2026, 9, 13));
        expect(gruppen[0].eintraege, [a, b]);
        expect(gruppen[1].tag, DateTime(2026, 9, 12));
        expect(gruppen[1].eintraege, [c]);
      },
    );

    test('Zeilen ohne Datum landen zusammen in einer eigenen Gruppe', () {
      final ohneDatum1 = _mail('x', null);
      final ohneDatum2 = _mail('y', null);
      final gruppen = gruppierePosteingangNachTag([ohneDatum1, ohneDatum2]);

      expect(gruppen, hasLength(1));
      expect(gruppen.single.eintraege, [ohneDatum1, ohneDatum2]);
    });
  });

  group('posteingangTagesbeschriftung', () {
    // 13.09.2026 ist ein Sonntag.
    final jetzt = DateTime(2026, 9, 13, 15);

    test('heute', () {
      expect(
        posteingangTagesbeschriftung(DateTime(2026, 9, 13), jetzt: jetzt),
        'Heute · 13.09.2026',
      );
    });

    test('gestern', () {
      expect(
        posteingangTagesbeschriftung(DateTime(2026, 9, 12), jetzt: jetzt),
        'Gestern · 12.09.2026',
      );
    });

    test('Wochentag innerhalb der letzten sieben Tage', () {
      expect(
        posteingangTagesbeschriftung(DateTime(2026, 9, 10), jetzt: jetzt),
        'Donnerstag · 10.09.2026',
      );
    });

    test('länger als sieben Tage zurück nur noch das Datum', () {
      expect(
        posteingangTagesbeschriftung(DateTime(2026, 9, 1), jetzt: jetzt),
        '01.09.2026',
      );
    });

    test('ueber die Sommerzeitumstellung bleibt der Vortag "Gestern" — die '
        'Nacht 29./30.03.2026 hat lokal nur 23 Stunden', () {
      expect(
        posteingangTagesbeschriftung(
          DateTime(2026, 3, 29),
          jetzt: DateTime(2026, 3, 30),
        ),
        'Gestern · 29.03.2026',
      );
    });
  });
}
