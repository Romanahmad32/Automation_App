import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_aktionsleiste.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const eintrag = PosteingangEintrag(
    id: 'id-1',
    betreff: 'Unfall vom 12.03.',
    absender: '"HUK-Coburg" <schaden@huk.de>',
    absenderAdresse: 'schaden@huk.de',
  );

  Widget bauen({Vorgang? vorgang}) => MaterialApp(
    home: Scaffold(
      body: PosteingangAktionsleiste(
        eintrag: eintrag,
        inhalt: null,
        vorgang: vorgang,
        onAntworten: () {},
        onMailInDieAkte: () {},
        onMailBeimVersand: () {},
      ),
    ),
  );

  testWidgets('zeigt genau drei Knöpfe, nur "Antworten" gefüllt', (
    tester,
  ) async {
    await tester.pumpWidget(bauen());

    expect(find.text('Antworten'), findsOneWidget);
    expect(find.text('In die Akte'), findsOneWidget);
    expect(find.text('Beim Versand verwenden'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
  });

  testWidgets('löst die drei übergebenen Callbacks aus', (tester) async {
    var antworten = 0;
    var inDieAkte = 0;
    var beimVersand = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosteingangAktionsleiste(
            eintrag: eintrag,
            inhalt: null,
            onAntworten: () => antworten++,
            onMailInDieAkte: () => inDieAkte++,
            onMailBeimVersand: () => beimVersand++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Antworten'));
    await tester.tap(find.text('In die Akte'));
    await tester.tap(find.text('Beim Versand verwenden'));

    expect(antworten, 1);
    expect(inDieAkte, 1);
    expect(beimVersand, 1);
  });

  Future<void> zeigeBei(WidgetTester tester, double breite) async {
    tester.view.physicalSize = Size(breite, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: Schriftstufe.amGroessten,
        ).light(),
        home: Scaffold(
          body: PosteingangAktionsleiste(
            eintrag: eintrag,
            inhalt: null,
            onAntworten: () {},
            onMailInDieAkte: () {},
            onMailBeimVersand: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // Die Leiste steht in einem `Wrap`, damit sie bei „Am größten" und
  // schmalem Fenster umbricht, statt seitlich überzulaufen (§4.5).
  testWidgets('läuft bei "Am größten" und 420px nicht über', (tester) async {
    await zeigeBei(tester, 420);

    expect(tester.takeException(), isNull);
  });
}
