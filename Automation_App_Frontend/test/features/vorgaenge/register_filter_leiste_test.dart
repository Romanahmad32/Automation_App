import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_reihenfolge.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_filter_leiste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// Das Rechtsgebiet-Dropdown war fest auf 200 px — mit der angehobenen
/// Schrift (Issue #57) passte „Alle Rechtsgebiete"/„Alle Zeilen" nicht mehr
/// neben den Pfeil und lief rechts über. Der Test pumpt die Filterleiste mit
/// dem angehobenen Theme bei schmaler Fensterbreite und erwartet keine
/// RenderFlex-Überlauf-Exception.
///
/// Dazu die Jahrgangsspanne: Sie hat die Chipreihe je Jahrgang abgelöst, die
/// bei einem Registerbuch ab 2018 breiter war als die Tabelle darunter.
void main() {
  final geaendert = <RegisterFilter>[];

  setUp(geaendert.clear);

  Future<void> zeigeFilterleiste(
    WidgetTester tester, {
    required double breite,
    RegisterFilter filter = RegisterFilter.alle,
    List<String> jahre = const ['2019', '2026'],
  }) async {
    tester.view.physicalSize = Size(breite, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(ThemeData.light().textTheme).light(),
        home: Scaffold(
          body: SizedBox(
            width: breite,
            child: RegisterFilterLeiste(
              filter: filter,
              alle: [for (final jahr in jahre) historieZeile(jahr: jahr)],
              onGeaendert: geaendert.add,
              reihenfolge: RegisterReihenfolge.vorgabe,
              onReihenfolge: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('überläuft nicht bei schmalem Fenster und angehobener Schrift', (
    tester,
  ) async {
    await zeigeFilterleiste(tester, breite: 500);

    expect(tester.takeException(), isNull);
  });

  /// Die Registerzeile trägt keinen Lebenszyklus — die Historie hat nie einen
  /// gehabt. Die Auswahl darf deshalb keinen versprechen.
  testWidgets('der Stand-Filter kennt zwei Werte, keine fünf Status', (
    tester,
  ) async {
    await zeigeFilterleiste(tester, breite: 1400);

    expect(find.text('Stand'), findsOneWidget);
    expect(find.text('Alle Zeilen'), findsOneWidget);
    expect(find.text('Angefragt'), findsNothing);
  });

  /// Nach der Übernahme besteht das Register zum größten Teil aus Historie —
  /// die laufende Arbeit der Kanzlei liegt sonst zwischen tausenden Altzeilen.
  testWidgets('die Herkunft lässt sich ein- und ausblenden', (tester) async {
    await zeigeFilterleiste(tester, breite: 1400);

    expect(find.text('Herkunft'), findsOneWidget);

    await tester.tap(find.text('Alle Herkünfte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vorgänge der App'));
    await tester.pumpAndSettle();

    expect(geaendert.single.quelle, RegisterQuellen.vorgang);
  });

  group('Jahrgangsspanne', () {
    /// Ohne gesetzte Grenze stehen dort die äußeren Jahrgänge des Bestands und
    /// nicht „Alle": So ist auf einen Blick ablesbar, wie weit das Register
    /// reicht.
    testWidgets('zeigt ohne Auswahl die Spanne des Bestands', (tester) async {
      await zeigeFilterleiste(tester, breite: 1400);

      expect(find.text('Von'), findsOneWidget);
      expect(find.text('Bis'), findsOneWidget);
      expect(find.text('2019'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
    });

    /// Ein Registerbuch ab 2018 ergab eine Chipreihe, die breiter war als die
    /// Tabelle — und beantwortete „die letzten drei Jahre" gar nicht.
    testWidgets('tritt an die Stelle eines Chips je Jahrgang', (tester) async {
      await zeigeFilterleiste(
        tester,
        breite: 1400,
        jahre: const ['2019', '2020', '2021', '2022', '2026'],
      );

      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('ein einzelner Jahrgang braucht keine Spanne', (tester) async {
      await zeigeFilterleiste(tester, breite: 1400, jahre: const ['2026']);

      expect(find.text('Von'), findsNothing);
      expect(find.text('Bis'), findsNothing);
    });

    testWidgets('eine gewählte Grenze meldet sich als Spanne', (tester) async {
      await zeigeFilterleiste(
        tester,
        breite: 1400,
        jahre: const ['2019', '2022', '2026'],
      );

      // „2019" steht im geschlossenen Feld „Von" — der Griff, es zu öffnen.
      // „2022" gibt es danach nur im aufgeklappten Menü.
      await tester.tap(find.text('2019'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2022'));
      await tester.pumpAndSettle();

      expect(geaendert.single.vonJahr, 2022);
    });
  });
}
