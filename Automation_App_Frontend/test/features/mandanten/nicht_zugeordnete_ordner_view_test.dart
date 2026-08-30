import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
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

    await tester.pumpWidget(seite(aufbau.bloc));
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

    await tester.pumpWidget(seite(aufbau.bloc));
    await tester.pumpAndSettle();

    // Ohne Präfix bleibt im Stapel: „Max Mustermann" kann eine
    // Verkehrsunfallsache sein.
    expect(find.text('Max Mustermann'), findsOneWidget);
    expect(find.text('Bußgeldsache Saeed'), findsNothing);
    expect(find.text('Verkehrsunfall (2)'), findsOneWidget);
    expect(find.text('Andere Ordner (2)'), findsOneWidget);
    expect(find.text('Ohne Mandantenbezug (0)'), findsOneWidget);

    // Beiseitegelegt heißt nicht gelöscht — ein Klick holt sie hervor.
    await tester.tap(find.text('Andere Ordner (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Bußgeldsache Saeed'), findsOneWidget);
    expect(find.text('Max Mustermann'), findsNothing);
  });

  testWidgets('die Suche greift auf den Ordnernamen', (tester) async {
    final aufbau = vierOrdner();
    addTearDown(aufbau.close);
    await aufbau.laden();

    await tester.pumpWidget(seite(aufbau.bloc));
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

    await tester.pumpWidget(seite(aufbau.bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Andere Ordner (2)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alle 2 als „ohne Mandantenbezug" markieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Markieren'));
    await tester.pumpAndSettle();

    expect(aufbau.ordnerStatus.setzAufrufe, 1);
    expect(find.text('Ohne Mandantenbezug (2)'), findsOneWidget);
    expect(find.text('Andere Ordner (0)'), findsOneWidget);
    // Der Stapel bleibt unberührt — die Aktion traf nur den gezeigten Topf.
    expect(find.text('Verkehrsunfall (2)'), findsOneWidget);
  });

  testWidgets('ein einzelner Ordner lässt sich vermerken und zurückholen', (
    tester,
  ) async {
    final aufbau = vierOrdner();
    addTearDown(aufbau.close);
    await aufbau.laden();

    await tester.pumpWidget(seite(aufbau.bloc));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Gehört keinem Mandanten').first);
    await tester.pumpAndSettle();
    expect(find.text('Verkehrsunfall (1)'), findsOneWidget);
    expect(find.text('Ohne Mandantenbezug (1)'), findsOneWidget);

    await tester.tap(find.text('Ohne Mandantenbezug (1)'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip('Vermerk zurücknehmen — zurück in den Stapel'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verkehrsunfall (2)'), findsOneWidget);
    expect(find.text('Ohne Mandantenbezug (0)'), findsOneWidget);
  });
}
