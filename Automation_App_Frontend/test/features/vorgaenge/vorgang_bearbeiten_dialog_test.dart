import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/form/kennzeichen_field.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_bearbeiten_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sachgebiete/sachgebiet_test_katalog.dart';

/// Der Bearbeiten-Dialog ist der zweite Weg, auf dem ein Kennzeichen in den
/// Bestand kommt — und der einzige ohne reactive_forms. Er hatte deshalb weder
/// Prüfung noch Normalisierung: Was hier getippt wurde, landete roh im Vorgang,
/// während dasselbe Feld beim Erfassen die Konvention `HG-E 1427` herstellte.
///
/// An dem Wert hängt die Zuordnung einer Zentralruf-Antwort
/// (`gleichesKennzeichen`), also gilt hier dieselbe Regel wie am Feld: lesbare
/// Schreibweisen werden geradegezogen, Unlesbares wird gar nicht erst
/// gespeichert.
void main() {
  setUp(registriereSachgebietKatalog);
  tearDown(() => getIt.reset());

  Vorgang basis({String? kennzeichen}) => Vorgang(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 3, 1),
    rechtsgebiet: RechtsgebietWert.verkehrsrecht,
    mandantName: 'Max Müller',
    geschaedigtenKennzeichen: kennzeichen,
  );

  /// Der gespeicherte Vorgang — `null`, solange nichts gespeichert wurde.
  late Vorgang? gespeichert;

  Future<void> zeigeDialog(WidgetTester tester, Vorgang vorgang) async {
    gespeichert = null;
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Über `showDialog` und nicht als Seiteninhalt: Der Dialog schliesst sich
    // nach dem Speichern selbst (`Navigator.pop`) — ohne eine Route über der
    // ersten liefe das ins Leere, und der Test prüfte einen Pfad, den es so
    // nicht gibt.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => VorgangBearbeitenDialog(
                  vorgang: vorgang,
                  onSave: (v) => gespeichert = v,
                  // Die Referenz bleibt in diesen Tests unangetastet; der
                  // Umweg über die Umbenennung läuft gar nicht erst an.
                  onReferenzAendern: (v, referenz) async =>
                      (vorgang: v, fehler: null),
                ),
              ),
              child: const Text('Vorgang bearbeiten'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Vorgang bearbeiten'));
    await tester.pumpAndSettle();
  }

  Finder kennzeichenFeld() => find.ancestor(
    of: find.text('Kennzeichen Mandant (z. B. HG-E 1427)'),
    matching: find.byType(TextField),
  );

  Future<void> speichere(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
  }

  testWidgets('speichert das Kennzeichen in der Konvention', (tester) async {
    await zeigeDialog(tester, basis());

    await tester.enterText(kennzeichenFeld(), 'hge1427');
    await speichere(tester);

    expect(gespeichert?.geschaedigtenKennzeichen, 'HG-E 1427');
  });

  testWidgets('weist ein unlesbares Kennzeichen ab, statt es zu speichern', (
    tester,
  ) async {
    await zeigeDialog(tester, basis(kennzeichen: 'HG-E 1427'));

    await tester.enterText(kennzeichenFeld(), 'der blaue Kombi');
    await speichere(tester);

    expect(gespeichert, isNull);
    expect(find.text(KennzeichenField.hinweis), findsOneWidget);
  });

  /// Ein leeres Feld heißt „nicht erfasst" — kein Grund, das Speichern
  /// aufzuhalten.
  testWidgets('speichert auch ohne Kennzeichen', (tester) async {
    await zeigeDialog(tester, basis(kennzeichen: 'HG-E 1427'));

    await tester.enterText(kennzeichenFeld(), '');
    await speichere(tester);

    expect(gespeichert, isNotNull);
    expect(gespeichert?.geschaedigtenKennzeichen, '');
  });
}
