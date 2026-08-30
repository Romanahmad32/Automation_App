import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/views/mandanten_import_view.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_datei_auswahl.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_eintrag_kachel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'import_testaufbau.dart';

Widget seite(MandantenImportCubit cubit) => MaterialApp(
  home: Scaffold(
    body: BlocProvider.value(
      value: cubit,
      child: BlocBuilder<MandantenImportCubit, MandantenImportState>(
        builder: (context, state) => MandantenImportView(state: state),
      ),
    ),
  ),
);

void main() {
  testWidgets('ohne Datei steht die Erklärung und die Auswahl', (tester) async {
    final aufbau = ImportTestaufbau();
    addTearDown(aufbau.close);

    await tester.pumpWidget(seite(aufbau.cubit));

    expect(find.byType(ImportDateiAuswahl), findsOneWidget);
    expect(find.text('JSON-Datei wählen'), findsOneWidget);
  });

  // Dieselbe Größenordnung wie beim Zuordnungsstapel: eine Importdatei über den
  // Produktivbestand hat viertausend Zeilen. Ein Widget-Test kann das Einfrieren
  // nicht messen, wohl aber seine Ursache — dass alle Kacheln gebaut werden.
  testWidgets('baut bei 4000 Zeilen nur die sichtbaren', (tester) async {
    final aufbau = ImportTestaufbau(
      antwort: bericht(
        eintraege: [
          for (var i = 0; i < 4000; i++) eintrag(i, name: 'Mandant Nr $i'),
        ],
        neu: 4000,
        ordnerZugeordnet: 4000,
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    await tester.pumpWidget(seite(aufbau.cubit));
    await tester.pumpAndSettle();

    // Voreinstellung „zu prüfen": 4000 unauffällige Zeilen, also keine.
    expect(find.text('0 von 4000 Zeilen in dieser Ansicht'), findsOneWidget);

    await tester.tap(find.text('Alle (4000)'));
    await tester.pumpAndSettle();

    final gebaut = tester.widgetList(find.byType(ImportEintragKachel)).length;
    expect(
      gebaut,
      lessThan(100),
      reason:
          'Es dürfen nur die sichtbaren Kacheln gebaut werden — gebaut wurden '
          '$gebaut von 4000. Eine ListView.builder statt einer Column.',
    );
    expect(gebaut, greaterThan(0));
  });

  testWidgets('die Zusammenfassung nennt die Ordner, nicht nur die Zeilen', (
    tester,
  ) async {
    final aufbau = ImportTestaufbau(
      antwort: bericht(
        eintraege: [eintrag(0)],
        neu: 1,
        ordnerZugeordnet: 3805,
        ohneMandantenbezug: 120,
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    await tester.pumpWidget(seite(aufbau.cubit));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('3805 Ordner bekommen einen Mandanten'),
      findsOneWidget,
    );
    expect(find.textContaining('120'), findsWidgets);
  });

  testWidgets('Übernehmen fragt nach und schreibt erst danach', (tester) async {
    final aufbau = ImportTestaufbau();
    addTearDown(aufbau.close);
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    await tester.pumpWidget(seite(aufbau.cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen'));
    await tester.pumpAndSettle();
    expect(find.text('Import übernehmen?'), findsOneWidget);
    expect(aufbau.importieren.schreibendeAufrufe, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    expect(aufbau.importieren.schreibendeAufrufe, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen').last);
    await tester.pumpAndSettle();

    expect(aufbau.importieren.schreibendeAufrufe, 1);
    expect(find.textContaining('Übernommen:'), findsOneWidget);
  });

  testWidgets('ein Hinweis steht offen an seiner Zeile', (tester) async {
    final aufbau = ImportTestaufbau(
      antwort: bericht(
        eintraege: [
          eintrag(
            0,
            art: ImportArt.abgelehnt,
            hinweise: const ['Ordner „X" gehört bereits Mark Schmidt.'],
          ),
        ],
        abgelehnt: 1,
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    await tester.pumpWidget(seite(aufbau.cubit));
    await tester.pumpAndSettle();

    expect(
      find.text('Ordner „X" gehört bereits Mark Schmidt.'),
      findsOneWidget,
    );
  });

  // Der Weg vom Bericht in den Dialog und zurück in die Datei — die Stelle,
  // die kein Cubit-Test sieht.
  testWidgets('eine auffällige Zeile lässt sich weglassen', (tester) async {
    final aufbau = ImportTestaufbau(
      antwort: bericht(
        eintraege: [
          eintrag(0, hinweise: const ['Ort weicht ab — nicht geändert.']),
        ],
        ergaenzt: 1,
        ordnerZugeordnet: 1,
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    await tester.pumpWidget(seite(aufbau.cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Zeile 1 bearbeiten'), findsOneWidget);
    expect(
      find.text('Ort weicht ab — nicht geändert.'),
      findsWidgets,
      reason: 'im Dialog muss stehen, was an der Zeile zu berichtigen wäre',
    );

    await tester.tap(find.text('Zeile weglassen'));
    await tester.pumpAndSettle();

    expect(aufbau.importieren.gesendet.last.mandanten, isEmpty);
    expect(aufbau.importieren.schreibendeAufrufe, 0);
  });

  testWidgets('eine berichtigte Anschrift landet in der Datei', (tester) async {
    final aufbau = ImportTestaufbau(
      antwort: bericht(
        eintraege: [
          eintrag(0, hinweise: const ['Ort weicht ab.']),
        ],
        ergaenzt: 1,
        ordnerZugeordnet: 1,
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');

    await tester.pumpWidget(seite(aufbau.cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.ancestor(of: find.text('Ort'), matching: find.byType(TextField)),
      'Frankfurt',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Änderung übernehmen'));
    await tester.pumpAndSettle();

    final geschickt = aufbau.importieren.gesendet.last.mandanten.single;
    expect(geschickt.ort, 'Frankfurt');
    expect(geschickt.bearbeitet, isTrue);
    expect(aufbau.importieren.schreibendeAufrufe, 0);
  });

  testWidgets('nach dem Übernehmen ist keine Zeile mehr änderbar', (
    tester,
  ) async {
    final aufbau = ImportTestaufbau(
      antwort: bericht(
        eintraege: [
          eintrag(0, hinweise: const ['Ort weicht ab.']),
        ],
        ergaenzt: 1,
        ordnerZugeordnet: 1,
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.cubit.dateiWaehlen('C:/tmp/import.json');
    await aufbau.cubit.uebernehmen();

    await tester.pumpWidget(seite(aufbau.cubit));
    await tester.pumpAndSettle();

    final knopf = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.edit_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(knopf.onPressed, isNull);
  });
}
