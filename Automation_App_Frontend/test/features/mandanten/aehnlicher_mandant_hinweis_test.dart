import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/aehnlicher_mandant_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

Widget hinweis(
  List<MandantVorschlag> vorschlaege, {
  void Function(Mandant)? onUebernehmen,
}) => MaterialApp(
  home: Scaffold(
    body: AehnlicherMandantHinweis(
      vorschlaege: vorschlaege,
      onUebernehmen: onUebernehmen ?? (_) {},
    ),
  ),
);

MandantVorschlag vorschlag(Mandant wer) =>
    MandantVorschlag(mandant: wer, begruendung: 'Ähnlicher Name im Register.');

void main() {
  testWidgets('ohne Treffer steht nichts da', (tester) async {
    await tester.pumpWidget(hinweis(const []));

    expect(find.byType(Card), findsNothing);
    expect(find.text('Übernehmen'), findsNothing);
  });

  testWidgets('nennt Name und Begründung des Treffers', (tester) async {
    await tester.pumpWidget(
      hinweis([vorschlag(mandant(1, 'Schmidt', vorname: 'Mark'))]),
    );

    expect(find.text('Ähnlicher Name im Register:'), findsOneWidget);
    expect(find.textContaining('Mark Schmidt'), findsOneWidget);
    expect(find.text('Ähnlicher Name im Register.'), findsOneWidget);
  });

  testWidgets('bei mehreren Treffern steht die Überschrift im Plural', (
    tester,
  ) async {
    await tester.pumpWidget(
      hinweis([
        vorschlag(mandant(1, 'Schmidt', vorname: 'Mark')),
        vorschlag(mandant(2, 'Schmitz', vorname: 'Anna')),
      ]),
    );

    expect(find.text('Ähnliche Namen im Register:'), findsOneWidget);
    expect(find.text('Übernehmen'), findsNWidgets(2));
  });

  testWidgets('Übernehmen meldet den angeklickten Mandanten', (tester) async {
    final gemeldet = <Mandant>[];
    await tester.pumpWidget(
      hinweis([
        vorschlag(mandant(7, 'Schmidt', vorname: 'Mark')),
      ], onUebernehmen: gemeldet.add),
    );

    await tester.tap(find.text('Übernehmen'));
    await tester.pump();

    expect(gemeldet.single.id, 7);
    expect(gemeldet.single.nachname, 'Schmidt');
  });
}
