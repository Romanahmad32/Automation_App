import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/paket_historie_tabelle.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnung_stand_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Arbeitspaket paket(
  int nummer, {
  DateTime? eingelesenAm,
  int ordner = 200,
  int erledigt = 0,
}) => Arbeitspaket(
  nummer: nummer,
  geholtAm: DateTime(2026, 9, 3, 9, 15),
  eingelesenAm: eingelesenAm,
  ordnerAnzahl: ordner,
  erledigtAnzahl: erledigt,
);

Widget band({
  int gesamt = 4040,
  int zugeordnet = 2871,
  int ohneBezug = 312,
  int offen = 857,
  List<Arbeitspaket> historie = const [],
}) => MaterialApp(
  home: Scaffold(
    body: ZuordnungStandBand(
      gesamt: gesamt,
      zugeordnet: zugeordnet,
      ohneBezug: ohneBezug,
      offen: offen,
      historie: historie,
    ),
  ),
);

void main() {
  testWidgets('zeigt alle vier Kennzahlen', (tester) async {
    await tester.pumpWidget(band());

    expect(find.text('4040'), findsOneWidget);
    expect(find.text('2871'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('857'), findsOneWidget);
    expect(find.text('offen'), findsOneWidget);
  });

  testWidgets('sagt es, wenn noch kein Paket geholt wurde', (tester) async {
    await tester.pumpWidget(band());

    expect(find.text('Noch kein Arbeitspaket geholt'), findsOneWidget);
  });

  testWidgets('zählt geholte und eingelesene Pakete', (tester) async {
    await tester.pumpWidget(
      band(
        historie: [
          paket(3),
          paket(2, eingelesenAm: DateTime(2026, 9, 4, 18, 2), erledigt: 198),
          paket(1, eingelesenAm: DateTime(2026, 9, 3, 11, 30), erledigt: 200),
        ],
      ),
    );

    expect(find.text('Pakete: 3 geholt, 2 eingelesen'), findsOneWidget);
  });

  // Die Historie kostet Platz, den die Arbeitsliste braucht — sie steht
  // deshalb hinter einem Klick und nicht dauerhaft offen.
  testWidgets('hält die Historie zu, bis jemand sie aufklappt', (tester) async {
    await tester.pumpWidget(band(historie: [paket(1)]));

    expect(find.byType(PaketHistorieTabelle), findsNothing);

    await tester.tap(find.text('Pakete: 1 geholt, 0 eingelesen'));
    await tester.pumpAndSettle();

    expect(find.byType(PaketHistorieTabelle), findsOneWidget);
  });

  // Genau darum geht es: Der Anwalt soll sehen, dass Paket 3 fehlt, bevor er
  // Paket 4 holt. Eine leere Zelle liest sich wie ein Darstellungsfehler.
  testWidgets('ein nicht eingelesenes Paket trägt einen Strich', (
    tester,
  ) async {
    await tester.pumpWidget(
      band(
        historie: [
          paket(2),
          paket(1, eingelesenAm: DateTime(2026, 9, 3, 11, 30), erledigt: 200),
        ],
      ),
    );
    await tester.tap(find.text('Pakete: 2 geholt, 1 eingelesen'));
    await tester.pumpAndSettle();

    expect(find.text('–'), findsOneWidget);
    expect(find.text('03.09.2026 11:30'), findsOneWidget);
  });

  testWidgets(
    'ohne Paket steht in der Tabelle ein Satz statt einer Leerzeile',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PaketHistorieTabelle(historie: [])),
        ),
      );

      expect(find.text('Noch kein Arbeitspaket geholt.'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    },
  );
}
