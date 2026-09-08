import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/historie_stand_karte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Karte „Historie" über dem Register (§6.2) ist die eine Stelle, an der
/// steht, was noch fehlt: Der Anwalt soll sehen, dass 2021 fehlt, *bevor* er
/// 2022 einliest.
void main() {
  JahrgangStand stand(int jahrgang, {List<int> luecken = const []}) =>
      JahrgangStand(
        jahrgang: jahrgang,
        zeilen: 200,
        hoechsteNummer: 200,
        luecken: luecken,
      );

  Future<void> zeigeKarte(
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
          body: HistorieStandKarte(
            stand: historie,
            onDateiEinlesen: onDateiEinlesen,
            onJahrgang: onJahrgang,
          ),
        ),
      ),
    );
  }

  testWidgets('ohne Übernahme sagt der Untertitel das auch', (tester) async {
    await zeigeKarte(tester, historie: RegisterHistorieStand.leer);

    expect(find.text('Historie'), findsOneWidget);
    expect(find.text('noch keine Historie übernommen'), findsOneWidget);
    // Kein festes Startjahr: Wie weit das Registerbuch zurückreicht, sagt der
    // Bestand und nicht eine Zahl im Code.
    expect(find.text('ab 2018'), findsNothing);
  });

  testWidgets('der Untertitel nennt den kleinsten übernommenen Jahrgang', (
    tester,
  ) async {
    await zeigeKarte(
      tester,
      historie: RegisterHistorieStand(jahrgaenge: [stand(2020), stand(2018)]),
    );

    expect(find.text('ab 2018'), findsOneWidget);
  });

  testWidgets('ein fehlender Jahrgang steht als „fehlt" zwischen seinen '
      'Nachbarn', (tester) async {
    await zeigeKarte(
      tester,
      historie: RegisterHistorieStand(
        jahrgaenge: [stand(2020), stand(2022)],
        fehlendeJahrgaenge: const [2021],
      ),
    );

    expect(find.text('2021'), findsOneWidget);
    expect(find.text('fehlt'), findsOneWidget);
  });

  /// Nach dem Übernehmen ist der Bericht des Imports weg — die offene Lücke
  /// bleibt und muss hier sichtbar sein.
  testWidgets('offene Lücken stehen mit ihrer Zahl am Jahrgang', (
    tester,
  ) async {
    await zeigeKarte(
      tester,
      historie: RegisterHistorieStand(
        jahrgaenge: [
          stand(2022, luecken: const [47, 48]),
          stand(2023, luecken: const [12]),
          stand(2024),
        ],
      ),
    );

    expect(find.text('2 Lücken'), findsOneWidget);
    expect(find.text('1 Lücke'), findsOneWidget);
    // Ein lückenloser Jahrgang trägt nur sein Häkchen, keine Beschriftung.
    expect(find.text('0 Lücken'), findsNothing);
  });

  testWidgets('ein Klick auf den Chip meldet den Jahrgang', (tester) async {
    final gewaehlt = <int>[];
    await zeigeKarte(
      tester,
      historie: RegisterHistorieStand(jahrgaenge: [stand(2019)]),
      onJahrgang: gewaehlt.add,
    );

    await tester.tap(find.text('2019'));
    await tester.pump();

    expect(gewaehlt, [2019]);
  });

  /// Der Knopf wird über einen Rückruf geprüft und nicht über die Route: Die
  /// Karte soll für sich testbar bleiben, ohne den Router der App.
  testWidgets('„Datei einlesen…" führt zur Import-Seite', (tester) async {
    var geoeffnet = 0;
    await zeigeKarte(
      tester,
      historie: RegisterHistorieStand.leer,
      onDateiEinlesen: () => geoeffnet++,
    );

    await tester.tap(find.text('Datei einlesen…'));
    await tester.pump();

    expect(geoeffnet, 1);
  });
}
