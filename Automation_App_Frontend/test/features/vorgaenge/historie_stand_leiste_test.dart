import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/historie_stand_leiste.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/jahrgang_stand_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Zeile „Historie" über dem Register (§6.2) ist die eine Stelle, an der
/// steht, was noch fehlt: Der Anwalt soll sehen, dass 2021 fehlt, *bevor* er
/// 2022 einliest.
///
/// Sie ist eine **Zeile** und keine Karte mehr: Der Satz sagt den Stand, die
/// Jahrgänge einzeln legt erst „Details" auf. Vorher nahm die ausgelegte
/// Chipreihe das obere Drittel der Seite ein, obwohl sie meist nur überflogen
/// wird.
void main() {
  JahrgangStand stand(int jahrgang, {List<int> luecken = const []}) =>
      JahrgangStand(
        jahrgang: jahrgang,
        zeilen: 200,
        hoechsteNummer: 200,
        luecken: luecken,
      );

  Future<void> zeigeLeiste(
    WidgetTester tester, {
    required RegisterHistorieStand historie,
    VoidCallback? onDateiEinlesen,
    ValueChanged<int>? onJahrgang,
  }) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistorieStandLeiste(
            stand: historie,
            onDateiEinlesen: onDateiEinlesen,
            onJahrgang: onJahrgang,
          ),
        ),
      ),
    );
  }

  testWidgets('ohne Übernahme sagt der Satz das auch', (tester) async {
    await zeigeLeiste(tester, historie: RegisterHistorieStand.leer);

    expect(find.text('Noch keine Historie übernommen'), findsOneWidget);
    // Kein festes Startjahr: Wie weit das Registerbuch zurückreicht, sagt der
    // Bestand und nicht eine Zahl im Code.
    expect(find.textContaining('ab 2018'), findsNothing);
    // Ohne Jahrgänge gibt es nichts aufzuklappen.
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('der Satz nennt den kleinsten übernommenen Jahrgang', (
    tester,
  ) async {
    await zeigeLeiste(
      tester,
      historie: RegisterHistorieStand(jahrgaenge: [stand(2020), stand(2018)]),
    );

    expect(find.text('Historie ab 2018'), findsOneWidget);
  });

  /// Was fehlt, steht im Satz — nicht erst hinter „Details". Sonst müsste der
  /// Anwalt aufklappen, um zu erfahren, dass es etwas aufzuklappen gibt.
  testWidgets('fehlende Jahrgänge und offene Lücken stehen im Satz', (
    tester,
  ) async {
    await zeigeLeiste(
      tester,
      historie: RegisterHistorieStand(
        jahrgaenge: [
          stand(2020, luecken: const [47, 48]),
          stand(2022, luecken: const [12]),
        ],
        fehlendeJahrgaenge: const [2021],
      ),
    );

    expect(
      find.text('Historie ab 2020 · 2021 fehlt · 3 offene Lücken'),
      findsOneWidget,
    );
  });

  testWidgets('ein lückenloser Bestand bleibt bei seinem Startjahr', (
    tester,
  ) async {
    await zeigeLeiste(
      tester,
      historie: RegisterHistorieStand(jahrgaenge: [stand(2024)]),
    );

    expect(find.text('Historie ab 2024'), findsOneWidget);
  });

  group('Details', () {
    testWidgets('die Jahrgänge stehen erst nach dem Aufklappen da', (
      tester,
    ) async {
      await zeigeLeiste(
        tester,
        historie: RegisterHistorieStand(
          jahrgaenge: [
            stand(2022, luecken: const [47, 48]),
          ],
          fehlendeJahrgaenge: const [2021],
        ),
      );

      expect(find.byType(JahrgangStandChip), findsNothing);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.byType(JahrgangStandChip), findsNWidgets(2));
      expect(find.text('fehlt'), findsOneWidget);
      expect(find.text('2 Lücken'), findsOneWidget);
    });

    testWidgets('ein Klick auf den Chip meldet den Jahrgang', (tester) async {
      final gewaehlt = <int>[];
      await zeigeLeiste(
        tester,
        historie: RegisterHistorieStand(jahrgaenge: [stand(2019)]),
        onJahrgang: gewaehlt.add,
      );
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2019'));
      await tester.pump();

      expect(gewaehlt, [2019]);
    });
  });

  /// Der Knopf wird über einen Rückruf geprüft und nicht über die Route: Die
  /// Zeile soll für sich testbar bleiben, ohne den Router der App.
  testWidgets('„Datei einlesen…" führt zur Import-Seite', (tester) async {
    var geoeffnet = 0;
    await zeigeLeiste(
      tester,
      historie: RegisterHistorieStand.leer,
      onDateiEinlesen: () => geoeffnet++,
    );

    await tester.tap(find.text('Datei einlesen…'));
    await tester.pump();

    expect(geoeffnet, 1);
  });

  /// Er führte auf dieselbe Seite wie „Datei einlesen…" — ein zweiter Weg zum
  /// selben Ziel, der nur Platz kostete.
  testWidgets('einen eigenen Knopf „Anleitung" gibt es nicht mehr', (
    tester,
  ) async {
    await zeigeLeiste(tester, historie: RegisterHistorieStand.leer);

    expect(find.text('Anleitung'), findsNothing);
  });
}
