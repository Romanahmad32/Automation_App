import 'package:automation_app/features/vorgaenge/presentation/blocs/register_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_state.dart';
import 'package:automation_app/features/vorgaenge/presentation/views/register_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_testaufbau.dart';

/// Eine historische Zeile lässt sich berichtigen — aber nur über die
/// Rückfrage. Hier wird der Bestand der Kanzlei geändert und nicht eine
/// Ansicht; ein Fehlklick in einer Tabelle mit tausenden Zeilen darf das nicht
/// auslösen.
void main() {
  late FakeRegisterZeilen zeilenPort;
  late FakeRegisterHistorie historiePort;
  late RegisterCubit register;

  setUp(() {
    zeilenPort = FakeRegisterZeilen(
      zeilen: [
        historieZeile(
          zeichen: '10/19-I C02',
          parteien: 'Bernd Mustermann ./. Beate Mustermann',
          sachbestand: 'Ehescheidung',
          historieId: 42,
        ),
      ],
    );
    historiePort = FakeRegisterHistorie(roh: rohZeile(id: 42));
    register = RegisterCubit(zeilenPort, historiePort);
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
              builder: (context, state) => RegisterView(state: state),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dialogOeffnenUndAusfuellen(WidgetTester tester) async {
    await tester.tap(find.text('10/19-I C02'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Änderung übernehmen'));
    await tester.pumpAndSettle();
  }

  /// Die Vorbelegung kommt aus der roh geladenen Zeile
  /// (`GET /api/RegisterHistorie/{id}`), nicht aus der Anzeigeform. Sähe der
  /// Anwalt leere Felder, wäre „Übernehmen" ein Löschbefehl.
  testWidgets('der Dialog steht mit den Feldern der Zeile da', (tester) async {
    await zeigeAnsicht(tester);

    await tester.tap(find.text('10/19-I C02'));
    await tester.pumpAndSettle();

    expect(historiePort.geladen, [42]);
    expect(find.text('Registereintrag 10/19-I C02 bearbeiten'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'C02'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Bernd Mustermann'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Beate Mustermann'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Ehescheidung'), findsOneWidget);
  });

  testWidgets('fragt nach, bevor geschrieben wird', (tester) async {
    await zeigeAnsicht(tester);

    await dialogOeffnenUndAusfuellen(tester);

    expect(find.text('Registereintrag ändern?'), findsOneWidget);
    // Bis hierher ist noch nichts geschrieben — der Dialog liefert nur die
    // Entscheidung zurück, die Rückfrage steht davor.
    expect(historiePort.geaendert, isEmpty);
  });

  testWidgets('ein „Abbrechen" in der Rückfrage schreibt nichts', (
    tester,
  ) async {
    await zeigeAnsicht(tester);
    await dialogOeffnenUndAusfuellen(tester);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(historiePort.geaendert, isEmpty);
  });

  testWidgets('nach der Zustimmung geht die Änderung an den Dienst', (
    tester,
  ) async {
    await zeigeAnsicht(tester);
    await dialogOeffnenUndAusfuellen(tester);

    await tester.tap(find.text('Ändern'));
    await tester.pumpAndSettle();

    expect(historiePort.geaendert, hasLength(1));
    expect(historiePort.geaendert.single.id, 42);
    expect(historiePort.geaendert.single.aenderung.abteilung, 'C02');
    expect(historiePort.geaendert.single.aenderung.mandant, 'Bernd Mustermann');
    expect(historiePort.geaendert.single.aenderung.gegner, 'Beate Mustermann');
    expect(find.textContaining('geändert.'), findsWidgets);
  });

  /// Ein Fehlschlag darf nicht als Erfolg durchgehen: Der Anwalt sähe sonst
  /// eine Zeile, die er für berichtigt hält, während im Bestand die alte steht.
  testWidgets('ein Fehlschlag wird gemeldet, nicht verschluckt', (
    tester,
  ) async {
    historiePort.fehler = Exception('404');
    await zeigeAnsicht(tester);
    await dialogOeffnenUndAusfuellen(tester);

    await tester.tap(find.text('Ändern'));
    await tester.pumpAndSettle();

    expect(find.textContaining('konnte nicht geändert werden'), findsWidgets);
  });
}
