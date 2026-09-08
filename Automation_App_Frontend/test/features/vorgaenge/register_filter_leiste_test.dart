import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_filter_leiste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// Das Rechtsgebiet-Dropdown war fest auf 200 px — mit der angehobenen
/// Schrift (Issue #57) passte „Alle rechtsgebiet"/„Alle Zeilen" nicht mehr
/// neben den Pfeil und lief rechts über. Der Test pumpt die Filterleiste mit
/// dem angehobenen Theme bei schmaler Fensterbreite und erwartet keine
/// RenderFlex-Überlauf-Exception.
void main() {
  Future<void> zeigeFilterleiste(
    WidgetTester tester, {
    required double breite,
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
              filter: RegisterFilter.alle,
              alle: [vorgangsZeile(), historieZeile()],
              onGeaendert: (_) {},
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
}
