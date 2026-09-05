import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_stand_karte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// „Stand dieser Vorlage" (#104, Stufe 2): die eine Stelle, an der steht, was
/// der Vorlage noch fehlt.
///
/// Der wichtigste Fall steht unten zuletzt: **Eine Datei ist kein Mangel.**
/// Die beiden Word-Dateien sind gleichwertig, und eine Vorlage, die nur die
/// eine braucht, darf dafür nicht angemahnt werden.
void main() {
  Future<void> zeige(
    WidgetTester tester,
    VorlagenStand stand, {
    void Function(List<String>)? onAlleUebernehmen,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VorlagenStandKarte(
            stand: stand,
            onAlleUebernehmen: onAlleUebernehmen,
          ),
        ),
      ),
    );
  }

  VorlagenStand stand({
    bool hatDateiOhne = true,
    bool hatDateiMit = false,
    List<String>? platzhalterOhne = const [],
    List<String>? platzhalterMit,
    List<String?> feldnamen = const [],
  }) => VorlagenStand.bestimme(
    hatDateiOhne: hatDateiOhne,
    hatDateiMit: hatDateiMit,
    platzhalterOhne: platzhalterOhne,
    platzhalterMit: platzhalterMit,
    feldnamen: feldnamen,
  );

  testWidgets('vollständig: die Karte sagt es in einem Satz und bietet nichts '
      'zum Übernehmen an', (tester) async {
    await zeige(
      tester,
      stand(platzhalterOhne: ['Kennzeichen'], feldnamen: ['Kennzeichen']),
      onAlleUebernehmen: (_) {},
    );

    expect(find.text('Stand dieser Vorlage'), findsOneWidget);
    expect(
      find.text('Vollständig — alle Platzhalter haben ein Feld'),
      findsOneWidget,
    );
    // Ohne offene Platzhalter verschwindet der Knopf, statt stumm dazustehen.
    expect(find.text('Alle übernehmen'), findsNothing);
    expect(find.textContaining('ohne Feld'), findsNothing);
  });

  testWidgets('ohne Word-Datei ist die Vorlage unvollständig — und die '
      'Dateizeile schweigt', (tester) async {
    // Der Mangel sagt schon, dass keine Datei da ist; eine zweite Zeile
    // „Verknüpft: nichts" wäre nur die Verneinung derselben Aussage.
    await zeige(tester, stand(hatDateiOhne: false, platzhalterOhne: null));

    expect(find.text('Keine Word-Datei verknüpft'), findsOneWidget);
    expect(find.textContaining('Verknüpft:'), findsNothing);
    expect(
      find.text('Vollständig — alle Platzhalter haben ein Feld'),
      findsNothing,
    );
  });

  testWidgets('offene Platzhalter: gezählt wird über beide Dateien, und der '
      'Knopf legt sie alle an', (tester) async {
    List<String>? uebernommen;
    await zeige(
      tester,
      stand(
        hatDateiMit: true,
        // „Frist" steht in beiden Dateien und zählt trotzdem nur einmal —
        // genau der Fehler, den die alte Zählzeile je Datei machte.
        platzhalterOhne: ['Kennzeichen', 'Frist'],
        platzhalterMit: ['Frist', 'Zeichen'],
        feldnamen: ['Kennzeichen'],
      ),
      onAlleUebernehmen: (namen) => uebernommen = namen,
    );

    expect(find.text('2 Platzhalter ohne Feld'), findsOneWidget);

    await tester.tap(find.text('Alle übernehmen'));
    expect(uebernommen, ['Frist', 'Zeichen']);
  });

  testWidgets('ein Feld ohne Vorkommen ist eine Warnung, kein Mangel', (
    tester,
  ) async {
    await zeige(
      tester,
      stand(
        platzhalterOhne: ['Kennzeichen'],
        feldnamen: ['Kennzeichen', 'Tippfelher'],
      ),
    );

    // Vollständig **und** gewarnt: Das Feld bleibt wirkungslos, aber das
    // erzeugte Dokument sieht deswegen nicht falsch aus.
    expect(
      find.text('Vollständig — alle Platzhalter haben ein Feld'),
      findsOneWidget,
    );
    expect(find.text('1 Feld in keiner Datei (Warnung)'), findsOneWidget);
  });

  testWidgets('eine einzelne Datei steht neutral da — kein Warnton für den '
      'leeren Slot', (tester) async {
    await zeige(
      tester,
      stand(platzhalterOhne: ['Kennzeichen'], feldnamen: ['Kennzeichen']),
    );
    expect(find.text('Verknüpft: ohne Schadensaufstellung'), findsOneWidget);

    await zeige(
      tester,
      stand(
        hatDateiOhne: false,
        hatDateiMit: true,
        platzhalterOhne: null,
        platzhalterMit: ['Kennzeichen'],
        feldnamen: ['Kennzeichen'],
      ),
    );
    expect(find.text('Verknüpft: mit Schadensaufstellung'), findsOneWidget);

    await zeige(
      tester,
      stand(
        hatDateiMit: true,
        platzhalterOhne: ['Kennzeichen'],
        platzhalterMit: ['Kennzeichen'],
        feldnamen: ['Kennzeichen'],
      ),
    );
    expect(
      find.text('Verknüpft: ohne und mit Schadensaufstellung'),
      findsOneWidget,
    );
  });

  testWidgets('was noch nicht gelesen ist, sagt die Karte dazu', (
    tester,
  ) async {
    await zeige(
      tester,
      stand(hatDateiMit: true, platzhalterOhne: ['Kennzeichen']),
    );

    expect(find.text('Platzhalter noch nicht gelesen'), findsOneWidget);
  });
}
