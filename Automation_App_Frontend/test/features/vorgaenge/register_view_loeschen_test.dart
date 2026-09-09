import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_state.dart';
import 'package:automation_app/features/vorgaenge/presentation/views/register_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// §6.3: Löschen im Register unterscheidet sich nach Herkunft der Zeile — eine
/// historische Zeile geht für sich, eine Vorgangszeile nur zusammen mit ihrem
/// Vorgang. Beides steht hier, weil `RegisterTabelle` selbst nur den Klick auf
/// den Papierkorb meldet (`register_tabelle_test.dart`).
void main() {
  late FakeRegisterZeilen zeilenPort;
  late FakeRegisterHistorie historiePort;
  late RegisterCubit register;
  late List<String> vorgangLoeschAufrufe;

  setUp(() {
    // Reihenfolge im Bestand, wie ihn das Backend liefert: Jahrgang
    // aufsteigend. Am Bildschirm gilt „neueste zuerst"
    // (`RegisterReihenfolge.vorgabe`) und dreht die Liste um — deshalb hier
    // absichtlich umgekehrt zur erwarteten Anzeigereihenfolge (historisch vor
    // Vorgang) eingetragen.
    zeilenPort = FakeRegisterZeilen(
      zeilen: [
        vorgangsZeile(zeichen: '01/26 C03', referenz: '01/26 C03_HG-E 1427'),
        historieZeile(zeichen: '10/19-I C02', historieId: 42),
      ],
    );
    historiePort = FakeRegisterHistorie();
    register = RegisterCubit(zeilenPort, historiePort);
    vorgangLoeschAufrufe = [];
  });

  tearDown(() => register.close());

  Future<void> zeigeAnsicht(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await register.lade();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: register),
              BlocProvider(
                create: (_) => RegisterSpiegelCubit(
                  FakeRegisterSpiegel(),
                  FakeRegisterPushNotifier(),
                ),
              ),
            ],
            child: BlocBuilder<RegisterCubit, RegisterState>(
              builder: (context, state) => RegisterView(
                state: state,
                onVorgangLoeschen: (referenz) async {
                  vorgangLoeschAufrufe.add(referenz);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('historische Zeile', () {
    testWidgets('fragt nach, bevor gelöscht wird', (tester) async {
      await zeigeAnsicht(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Registereintrag löschen?'), findsOneWidget);
      expect(historiePort.geloescht, isEmpty);
    });

    testWidgets('ein „Abbrechen" löscht nichts', (tester) async {
      await zeigeAnsicht(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(historiePort.geloescht, isEmpty);
    });

    testWidgets('nach der Zustimmung geht die Löschung an den Dienst', (
      tester,
    ) async {
      await zeigeAnsicht(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      expect(historiePort.geloescht, [42]);
      expect(find.textContaining('gelöscht.'), findsWidgets);
    });

    testWidgets('ein Fehlschlag wird gemeldet, nicht verschluckt', (
      tester,
    ) async {
      historiePort.fehler = Exception('404');
      await zeigeAnsicht(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('konnte nicht gelöscht werden'), findsWidgets);
    });
  });

  group('Zeile, die einen Vorgang spiegelt', () {
    testWidgets('sagt, dass die Zeile den Vorgang nicht überlebt', (
      tester,
    ) async {
      await zeigeAnsicht(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      expect(find.text('Vorgang mitlöschen?'), findsOneWidget);
      expect(
        find.textContaining('kann nicht für sich bestehen'),
        findsOneWidget,
      );
      // Keine Auswahl „nur die Zeile" — den Knopf gibt es fachlich nicht.
      expect(find.text('Nur die Zeile'), findsNothing);
      expect(vorgangLoeschAufrufe, isEmpty);
    });

    testWidgets('ein „Abbrechen" löscht keinen Vorgang', (tester) async {
      await zeigeAnsicht(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(vorgangLoeschAufrufe, isEmpty);
    });

    testWidgets(
      'nach der Zustimmung geht der Vorgang mit registerzeileBehalten: false',
      (tester) async {
        await zeigeAnsicht(tester);

        await tester.tap(find.byIcon(Icons.delete_outline).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Vorgang löschen'));
        await tester.pumpAndSettle();

        expect(vorgangLoeschAufrufe, ['01/26 C03_HG-E 1427']);
      },
    );
  });
}
