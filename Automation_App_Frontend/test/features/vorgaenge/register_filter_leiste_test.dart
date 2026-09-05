import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_filter_leiste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Rechtsgebiet-Dropdown war fest auf 200 px — mit der angehobenen
/// Schrift (Issue #57) passte „Alle rechtsgebiet"/„Alle status" nicht mehr
/// neben den Pfeil und lief rechts über. Der Test pumpt die Filterleiste mit
/// dem angehobenen Theme bei schmaler Fensterbreite und erwartet keine
/// RenderFlex-Überlauf-Exception.
void main() {
  Vorgang vorgang() => Vorgang(
    referenz: '1/26 C03_HG-E 1427',
    angefragtAm: DateTime(2026, 1, 5),
    jahr: '26',
    abteilung: 'C03',
  );

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
              alle: [vorgang()],
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
}
