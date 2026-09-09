import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/stand_karte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget seite(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('zeigt die vier Zähler des Zählerbands', (tester) async {
    await tester.pumpWidget(
      seite(
        StandKarte(
          gesamt: 4040,
          zugeordnet: 312,
          ohneBezug: 58,
          offen: 3670,
          pakete: const [],
          onPaketLoeschen: (_) {},
        ),
      ),
    );

    expect(find.text('Stand der Übernahme'), findsOneWidget);
    expect(find.text('4040'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
    expect(find.text('3670'), findsOneWidget);
    expect(find.text('gesamt'), findsOneWidget);
    expect(find.text('zugeordnet'), findsOneWidget);
    expect(find.text('ohne Bezug'), findsOneWidget);
    expect(find.text('offen'), findsOneWidget);
  });

  testWidgets('nennt zuletzt geholt am, solange die Historie zugeklappt ist', (
    tester,
  ) async {
    await tester.pumpWidget(
      seite(
        StandKarte(
          gesamt: 10,
          zugeordnet: 5,
          ohneBezug: 1,
          offen: 4,
          pakete: [
            ImportPaket(
              nummer: 1,
              geholtAm: DateTime.utc(2026, 9, 5, 8),
              anzahlOrdner: 100,
            ),
          ],
          onPaketLoeschen: (_) {},
        ),
      ),
    );

    expect(find.textContaining('zuletzt geholt am'), findsOneWidget);

    await tester.tap(find.text('Pakete (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('zuletzt geholt am'), findsNothing);
  });

  testWidgets(
    'die Historie zeigt ein offenes Paket als 137 von 200 und ein fertiges '
    'mit Datum',
    (tester) async {
      await tester.pumpWidget(
        seite(
          StandKarte(
            gesamt: 400,
            zugeordnet: 100,
            ohneBezug: 0,
            offen: 300,
            pakete: [
              ImportPaket(
                nummer: 3,
                geholtAm: DateTime.utc(2026, 9, 5),
                anzahlOrdner: 200,
                erledigt: 137,
              ),
              ImportPaket(
                nummer: 2,
                geholtAm: DateTime.utc(2026, 9, 4),
                anzahlOrdner: 200,
                erledigt: 200,
                eingelesenAm: DateTime.utc(2026, 9, 4),
                zeilen: 200,
              ),
            ],
            onPaketLoeschen: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Pakete (2)'));
      await tester.pumpAndSettle();

      expect(find.text('137 von 200'), findsOneWidget);
      expect(find.text('200 von 200'), findsOneWidget);
      // Offenes Paket: „eingelesen" und „Zeilen" stehen auf „–".
      expect(find.text('–'), findsNWidgets(2));
      // Fertiges Paket trägt ein Datum in „eingelesen".
      expect(find.text('04.09.2026'), findsNWidgets(2));
    },
  );

  testWidgets('ohne Pakete steht ein Hinweis statt einer leeren Tabelle', (
    tester,
  ) async {
    await tester.pumpWidget(
      seite(
        StandKarte(
          gesamt: 0,
          zugeordnet: 0,
          ohneBezug: 0,
          offen: 0,
          pakete: const [],
          onPaketLoeschen: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Pakete (0)'));
    await tester.pumpAndSettle();

    expect(find.text('Noch kein Arbeitspaket geholt.'), findsOneWidget);
  });
}
