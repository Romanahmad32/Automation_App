import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/gesendet_liste.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/gesendet_zeile.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Liste des Bereichs „Gesendet" (§4.3): Tagesgruppen wie im Posteingang,
/// je Zeile Empfänger, Betreff, Vorgangs-Pille, Anhangszahl und die
/// Unterscheidung „Gesendet" ↔ „In Outlook geöffnet".
void main() {
  final versendet = VersandEintrag(
    vorgangReferenz: '144/2026 K_HG-E 1427',
    gesendetAm: DateTime(2026, 9, 13, 11, 5),
    weg: VersandWeg.direktversand,
    empfaenger: const ['schaden@huk-coburg.de'],
    betreff: 'Anspruchsschreiben zum Unfall vom 12.05.2026',
    anhaenge: const ['Anspruchsschreiben.pdf', 'Gutachten.pdf'],
    imGesendetOrdner: true,
  );
  final uebergeben = VersandEintrag(
    vorgangReferenz: '145/2026 K_M-AB 2026',
    gesendetAm: DateTime(2026, 9, 12, 16, 40),
    weg: VersandWeg.outlookEntwurf,
    empfaenger: const ['post@allianz.de'],
    betreff: 'Nachfrage Schadennummer',
  );

  Future<void> zeigeListe(
    WidgetTester tester, {
    required List<VersandEintrag> eintraege,
    double breite = 900,
    Schriftstufe schriftstufe = Schriftstufe.normal,
  }) async {
    tester.view.physicalSize = Size(breite, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: schriftstufe,
        ).light(),
        home: Scaffold(
          body: GesendetListe(
            eintraege: eintraege,
            zeichen: const {'144/2026 k_hg-e 1427': '144/26 C03'},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('die Zeile nennt Empfaenger, Betreff, Zeichen und Anhangszahl', (
    tester,
  ) async {
    await zeigeListe(tester, eintraege: [versendet]);

    expect(find.text('schaden@huk-coburg.de'), findsOneWidget);
    expect(
      find.text('Anspruchsschreiben zum Unfall vom 12.05.2026'),
      findsOneWidget,
    );
    // Das Zeichen, nicht die volle Referenz — so steht es überall sonst auch.
    expect(find.text('144/26 C03'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Gesendet'), findsOneWidget);
  });

  testWidgets('eine Uebergabe an Outlook heisst nicht "Gesendet"', (
    tester,
  ) async {
    await zeigeListe(tester, eintraege: [uebergeben]);

    expect(find.text('In Outlook geöffnet'), findsOneWidget);
    expect(find.text('Gesendet'), findsNothing);
    // Ohne aufgeloestes Zeichen steht die Referenz da, statt gar nichts.
    expect(find.text('145/2026 K_M-AB 2026'), findsOneWidget);
  });

  testWidgets('ohne Anhaenge fehlt die Bueroklammer', (tester) async {
    await zeigeListe(tester, eintraege: [uebergeben]);

    expect(find.byIcon(Icons.attach_file), findsNothing);
  });

  testWidgets('zwei Tage ergeben zwei Gruppenkoepfe', (tester) async {
    await zeigeListe(tester, eintraege: [versendet, uebergeben]);

    expect(find.byType(GesendetZeile), findsNWidgets(2));
    expect(find.textContaining('13.09.2026'), findsOneWidget);
    expect(find.textContaining('12.09.2026'), findsOneWidget);
  });

  testWidgets('leer sagt die Liste es, statt leer zu bleiben', (tester) async {
    await zeigeListe(tester, eintraege: const []);

    expect(find.text('Noch nichts aus der App versendet.'), findsOneWidget);
    expect(find.byType(GesendetZeile), findsNothing);
  });

  testWidgets('bei "Am groessten" und 360 px laeuft keine Zeile ueber', (
    tester,
  ) async {
    await zeigeListe(
      tester,
      eintraege: [versendet, uebergeben],
      breite: 360,
      schriftstufe: Schriftstufe.amGroessten,
    );

    expect(find.byType(StatusPille), findsWidgets);
    expect(
      tester.takeException(),
      isNull,
      reason:
          'Empfänger, Betreff und die Pillenreihe stehen in einer schmalen '
          'Spalte; bei „Am größten" muss die Reihe umbrechen statt '
          'überzulaufen.',
    );
  });
}
