import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:automation_app/features/mandanten/presentation/views/nicht_zugeordnete_ordner_view.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/nicht_zugeordneter_ordner_kachel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

Widget seite(MandantenOverviewBloc bloc) => MaterialApp(
  home: Scaffold(
    body: BlocProvider.value(
      value: bloc,
      child: BlocBuilder<MandantenOverviewBloc, MandantenOverviewState>(
        builder: (context, state) => state is MandantenOverviewLoaded
            ? NichtZugeordneteOrdnerView(state: state)
            : const SizedBox.shrink(),
      ),
    ),
  ),
);

/// Baut [seite] in einer Fenstergröße, wie sie die Kanzlei-App wirklich hat —
/// die neue Stand-Karte (Issue #108) braucht mehr Höhe, als das
/// Standard-Testfenster von `flutter_test` (800×600) hergibt.
Future<void> pumpSeite(WidgetTester tester, MandantenOverviewBloc bloc) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(seite(bloc));
}

/// Vier Ordner, die die drei Töpfe abdecken: zwei Verkehrsunfall-Kandidaten
/// (einer davon ohne Präfix) und zwei andere Sachgebiete.
MandantenTestaufbau vierOrdner() => MandantenTestaufbau(
  akten: [
    akte('VUnfallursache Mark'),
    akte('Max Mustermann'),
    akte('Bußgeldsache Saeed'),
    akte('FamSache Mark Müller'),
  ],
);

void main() {
  // Der Fehler aus dem Bericht in seiner Größenordnung: 4040 Ordner in einer
  // `Column` haben die Seite eingefroren. Ein Widget-Test kann das Einfrieren
  // nicht messen, wohl aber seine Ursache — dass alle Kacheln gebaut werden.
  testWidgets('baut bei 4000 offenen Ordnern nur die sichtbaren Zeilen', (
    tester,
  ) async {
    final aufbau = MandantenTestaufbau(
      akten: [for (var i = 0; i < 4000; i++) akte('VUnfallursache Nr $i')],
    );
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    final gebaut = tester
        .widgetList(find.byType(NichtZugeordneterOrdnerKachel))
        .length;
    expect(
      gebaut,
      lessThan(100),
      reason:
          'Es dürfen nur die sichtbaren Kacheln gebaut werden — gebaut wurden '
          '$gebaut von 4000. Eine ListView.builder statt einer Column.',
    );
    expect(gebaut, greaterThan(0));
    expect(
      find.text('4000 von 4000 Ordnern in dieser Ansicht'),
      findsOneWidget,
    );
  });

  testWidgets('teilt die Ordner in Töpfe und nennt jede Zahl', (tester) async {
    final aufbau = vierOrdner();
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    // Ohne Präfix bleibt im Stapel: „Max Mustermann" kann eine
    // Verkehrsunfallsache sein.
    expect(find.text('Max Mustermann'), findsOneWidget);
    expect(find.text('Bußgeldsache Saeed'), findsNothing);
    expect(find.text('Zuzuordnen (2)'), findsOneWidget);
    expect(find.text('Andere Sachgebiete (2)'), findsOneWidget);
    expect(find.text('Beiseitegelegt (0)'), findsOneWidget);

    // Beiseitegelegt heißt nicht gelöscht — ein Klick holt sie hervor.
    await tester.tap(find.text('Andere Sachgebiete (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Bußgeldsache Saeed'), findsOneWidget);
    expect(find.text('Max Mustermann'), findsNothing);
  });

  testWidgets('die Suche greift auf den Ordnernamen', (tester) async {
    final aufbau = vierOrdner();
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.enterText(find.byType(TextField), 'muster');
    await tester.pumpAndSettle();

    expect(find.text('Max Mustermann'), findsOneWidget);
    expect(find.text('VUnfallursache Mark'), findsNothing);
  });

  // Stufe 3 aus Issue #19: einzeln ist auch der gefilterte Rest nicht zu
  // schaffen. Die Aktion wirkt auf genau das, was gerade in der Liste steht.
  testWidgets('markiert den gefilterten Topf in einem Zug', (tester) async {
    final aufbau = vierOrdner();
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Andere Sachgebiete (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alle 2 als „ohne Mandantenbezug" markieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Markieren'));
    await tester.pumpAndSettle();

    expect(aufbau.ordnerStatus.setzAufrufe, 1);
    expect(find.text('Beiseitegelegt (2)'), findsOneWidget);
    expect(find.text('Andere Sachgebiete (0)'), findsOneWidget);
    // Der Stapel bleibt unberührt — die Aktion traf nur den gezeigten Topf.
    expect(find.text('Zuzuordnen (2)'), findsOneWidget);
  });

  testWidgets('ein einzelner Ordner lässt sich vermerken und zurückholen', (
    tester,
  ) async {
    final aufbau = vierOrdner();
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Gehört keinem Mandanten').first);
    await tester.pumpAndSettle();
    expect(find.text('Zuzuordnen (1)'), findsOneWidget);
    expect(find.text('Beiseitegelegt (1)'), findsOneWidget);

    await tester.tap(find.text('Beiseitegelegt (1)'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip('Vermerk zurücknehmen — zurück in den Stapel'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zuzuordnen (2)'), findsOneWidget);
    expect(find.text('Beiseitegelegt (0)'), findsOneWidget);
  });

  // „Aus Versehen das falsche Paket geholt" ist der Grund, warum es den
  // Zurücknehmen-Knopf gibt: Er entfernt die Buchführungszeile und rührt
  // keinen Ordner an. Bestätigt wird im Dialog — ein Klick daneben soll sich
  // nicht sofort auswirken.
  testWidgets('nimmt ein offenes Paket nach Bestätigung zurück', (
    tester,
  ) async {
    final aufbau = MandantenTestaufbau(
      akten: [akte('VUnfallursache Mark')],
      importPakete: [
        ImportPaket(nummer: 1, geholtAm: angelegt, anzahlOrdner: 2),
      ],
    );
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pakete (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Paket zurücknehmen'));
    await tester.pumpAndSettle();

    // Abbrechen lässt das Paket stehen.
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(aufbau.paketeSpeicher.loeschAufrufe, 0);

    await tester.tap(find.byTooltip('Paket zurücknehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zurücknehmen'));
    await tester.pumpAndSettle();

    expect(aufbau.paketeSpeicher.loeschAufrufe, 1);
    expect(aufbau.paketeSpeicher.pakete, isEmpty);
    // Der Ordner bleibt im Stapel — das Paket war nur eine Buchführungszeile.
    expect(find.text('VUnfallursache Mark'), findsOneWidget);
  });

  testWidgets('ein eingelesenes Paket trägt keinen Zurücknehmen-Knopf', (
    tester,
  ) async {
    final aufbau = MandantenTestaufbau(
      akten: [akte('VUnfallursache Mark')],
      importPakete: [
        ImportPaket(
          nummer: 1,
          geholtAm: angelegt,
          anzahlOrdner: 2,
          erledigt: 2,
          eingelesenAm: angelegt,
          zeilen: 2,
        ),
      ],
    );
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pakete (1)'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Paket zurücknehmen'), findsNothing);
  });

  // Ein `Column` mit `Expanded`-Liste lief über, sobald Kopf (Ablauf-Hinweis
  // aufgeklappt) und Liste zusammen nicht mehr in ein kleines Fenster passten
  // — der `CustomScrollView` teilt sich stattdessen eine Scrollleiste.
  testWidgets(
    'kein Overflow auf kleinem Fenster mit aufgeklapptem Ablauf-Hinweis',
    (tester) async {
      tester.view.physicalSize = const Size(900, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final aufbau = vierOrdner();
      addTearDown(aufbau.close);
      await aufbau.laden();

      FlutterErrorDetails? erfasst;
      final vorherige = FlutterError.onError;
      FlutterError.onError = (details) => erfasst ??= details;
      addTearDown(() => FlutterError.onError = vorherige);

      await tester.pumpWidget(seite(aufbau.bloc));
      await tester.pumpAndSettle();

      final titel = find.text('So werden viele Ordner auf einmal zugeordnet');
      expect(titel, findsOneWidget);
      await tester.tap(titel);
      await tester.pumpAndSettle();

      expect(
        erfasst,
        isNull,
        reason: 'RenderFlex-Overflow beim Aufklappen: $erfasst',
      );
    },
  );
  testWidgets('zeigt zunächst nur eine Portion und sagt, wie viele fehlen', (
    tester,
  ) async {
    final aufbau = MandantenTestaufbau(
      akten: [for (var i = 0; i < 4000; i++) akte('VUnfallursache Nr $i')],
    );
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    // Die Kopfzeile nennt weiterhin den ganzen Topf — die Portion ist eine
    // Frage der Anzeige und nicht des Arbeitsvorrats.
    expect(
      find.text('4000 von 4000 Ordnern in dieser Ansicht'),
      findsOneWidget,
    );

    // Der Listenfuß mit „50 von 4000" steht hinter fünfzig Kacheln und ist
    // deshalb gar nicht gebaut; geprüft wird die Portion dort, wo sie
    // entsteht.
    final geladen = aufbau.bloc.state as MandantenOverviewLoaded;
    expect(geladen.angezeigteNichtZugeordnete, hasLength(50));
    expect(geladen.sichtbareNichtZugeordnete, hasLength(4000));
    expect(geladen.gibtWeitereOrdner, isTrue);
  });

  testWidgets('weiterscrollen zeigt die nächste Portion', (tester) async {
    final aufbau = MandantenTestaufbau(
      akten: [for (var i = 0; i < 4000; i++) akte('VUnfallursache Nr $i')],
    );
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pumpAndSettle();

    expect(
      aufbau.bloc.state,
      isA<MandantenOverviewLoaded>().having(
        (s) => s.sichtbareOrdnerGrenze,
        'sichtbareOrdnerGrenze',
        greaterThan(50),
      ),
      reason: 'Am Listenende muss die nächste Portion dazukommen.',
    );
  });

  testWidgets('ein Topfwechsel fängt wieder bei der ersten Portion an', (
    tester,
  ) async {
    final aufbau = MandantenTestaufbau(
      akten: [
        for (var i = 0; i < 200; i++) akte('VUnfallursache Nr $i'),
        for (var i = 0; i < 200; i++) akte('Bußgeldsache Nr $i'),
      ],
    );
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    aufbau.bloc.add(const ZeigeWeitereOrdnerEvent());
    await tester.pumpAndSettle();
    expect(
      (aufbau.bloc.state as MandantenOverviewLoaded).sichtbareOrdnerGrenze,
      100,
    );

    aufbau.bloc.add(
      const SetzeZuordnungFilterEvent(
        ZuordnungFilter(ansicht: OrdnerAnsicht.andere),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      (aufbau.bloc.state as MandantenOverviewLoaded).sichtbareOrdnerGrenze,
      50,
      reason:
          'Sonst zeigte der nächste Topf ohne Zutun so viele Zeilen, wie im '
          'vorigen erscrollt wurden.',
    );
  });
  testWidgets('sagt unter „Zuzuordnen", wie viel davon erkannt wurde', (
    tester,
  ) async {
    // Von den beiden Ordnern im Topf trägt einer ein Präfix, der andere
    // nicht — die Zahl 2 allein sähe nach zwei erkannten Unfallsachen aus.
    final aufbau = vierOrdner();
    addTearDown(aufbau.close);
    await aufbau.laden();

    await pumpSeite(tester, aufbau.bloc);
    await tester.pumpAndSettle();

    expect(find.text('Zuzuordnen (2)'), findsOneWidget);
    expect(
      find.textContaining(
        'Darin 1 mit Verkehrsunfall-Präfix erkannt und 1, deren Name keinen '
        'Aktentyp nennt',
      ),
      findsOneWidget,
    );
  });
}
