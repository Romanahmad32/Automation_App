import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandant_akten_liste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

/// Die Akten an der aufgeklappten Mandantenkarte (#132): öffnen, zuordnen,
/// lösen. Das Öffnen läuft über die Naht [DateiOeffner.oeffneOrdner] — ein
/// Widget-Test darf keinen Explorer starten.
void main() {
  const fallPfad = 'C:/Akten/VUnfallursache Müller/Unfall v. 12.05.2019';

  late MandantenTestaufbau aufbau;
  late List<String> geoeffnet;

  setUp(() {
    geoeffnet = [];
    DateiOeffner.oeffneOrdner = (pfad) async {
      geoeffnet.add(pfad);
      return true;
    };
    addTearDown(DateiOeffner.zuruecksetzen);
  });

  MandantenOverviewLoaded stand() =>
      aufbau.bloc.state as MandantenOverviewLoaded;

  Mandant mueller() => stand().mandanten.firstWhere((m) => m.id == 1);

  /// Baut den Bloc **im** Test und nicht in `setUp`: `testWidgets` läuft in
  /// einer Fake-Async-Zone, und ein außerhalb gebauter Bloc verarbeitet seine
  /// Ereignisse in der echten — dann wartet der Test auf einen Zustand, der
  /// nie kommt, und hängt ohne Zeitgrenze (wie `mandant_card_test.dart`).
  Future<void> zeige(WidgetTester tester) async {
    aufbau = MandantenTestaufbau(
      register: [
        mandant(1, 'Müller', ordner: ['VUnfallursache Müller', 'Umbenannt']),
        mandant(2, 'Schulz', ordner: ['Strafsache Schulz']),
      ],
      akten: [
        akte('VUnfallursache Müller'),
        akte('Strafsache Schulz'),
        akte('Bußgeldsache Müller'),
      ],
      faelle: [
        Fall(
          name: 'Unfall v. 12.05.2019',
          pfad: fallPfad,
          geaendertAm: angelegt,
        ),
      ],
    );
    addTearDown(aufbau.close);
    final geladen = await aufbau.laden();
    aufbau.bloc.add(LadeFaelleEvent(geladen.akten.first));
    await aufbau.naechster();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: aufbau.bloc,
            child: SingleChildScrollView(
              child: MandantAktenListe(mandant: mueller(), state: stand()),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Akte und Fall öffnen sich im Explorer', (tester) async {
    await zeige(tester);

    await tester.tap(find.byTooltip('Akte im Explorer öffnen'));
    await tester.tap(find.text('• Unfall v. 12.05.2019'));
    await tester.pumpAndSettle();

    expect(geoeffnet, ['C:/Akten/VUnfallursache Müller', fallPfad]);
  });

  testWidgets('ein fehlender Ordner wird gemeldet, nicht verschluckt', (
    tester,
  ) async {
    DateiOeffner.oeffneOrdner = (_) async => false;
    await zeige(tester);

    await tester.tap(find.byTooltip('Akte im Explorer öffnen'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Der Ordner „VUnfallursache Müller" wurde nicht gefunden — umbenannt '
        'oder verschoben? Neu laden zeigt den aktuellen Stand.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('eine Zuordnung ohne gefundenen Ordner steht da und lässt sich '
      'lösen', (tester) async {
    await zeige(tester);

    expect(find.text('Umbenannt'), findsOneWidget);
    expect(
      find.text('Nicht im Stammordner gefunden — umbenannt oder verschoben?'),
      findsOneWidget,
    );

    // Zwei Lösen-Knöpfe: an der gefundenen Akte und am fehlenden Ordner.
    await tester.tap(find.byTooltip('Zuordnung lösen').last);
    await tester.pumpAndSettle();
    expect(find.text('Zuordnung lösen?'), findsOneWidget);

    await tester.tap(find.text('Lösen'));
    await tester.pumpAndSettle();

    expect(mueller().aktenOrdnernamen, ['VUnfallursache Müller']);
    expect(aufbau.getAkten.aufrufe, 1);
  });

  testWidgets('wer die Rückfrage abbricht, löst nichts', (tester) async {
    await zeige(tester);

    await tester.tap(find.byTooltip('Zuordnung lösen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(mueller().aktenOrdnernamen, hasLength(2));
  });

  testWidgets('Akte zuordnen: Vorschlag oben, fremder Ordner gesperrt, die '
      'Wahl ordnet zu und nimmt den Ordner aus dem Stapel', (tester) async {
    await zeige(tester);

    await tester.tap(find.text('Akte zuordnen …'));
    await tester.pumpAndSettle();

    final kacheln = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(
      [for (final k in kacheln) (k.title as Text).data],
      ['Bußgeldsache Müller', 'Strafsache Schulz'],
    );
    expect(kacheln.first.enabled, isTrue);
    expect(find.text('Passt zum Namen'), findsOneWidget);
    expect(kacheln.last.enabled, isFalse);
    expect(find.text('Gehört bereits einem anderen Mandanten'), findsOneWidget);

    await tester.tap(find.text('Bußgeldsache Müller'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(mueller().aktenOrdnernamen, contains('Bußgeldsache Müller'));
    expect([
      for (final a in stand().nichtZugeordneteAkten) a.ordnername,
    ], isEmpty);
    expect(aufbau.getAkten.aufrufe, 1);
    // Die Karte ist aufgeklappt: Die Fälle der neuen Akte kommen nach.
    expect(aufbau.getFaelle.aufrufe, 2);
  });
}
