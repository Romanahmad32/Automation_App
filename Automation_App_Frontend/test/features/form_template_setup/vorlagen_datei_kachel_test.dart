import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_datei_kachel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Eine Wahlfläche der Auswahlseite (#104 Stufe 5): Sie trägt nicht mehr nur
/// einen Knopf, sondern **ihren Zustand** — welche Datei hängt dran, ist sie
/// gelesen, und was lässt sich damit tun.
///
/// Ohne Bloc geprüft: Die Kachel bekommt ihren [SlotPlaceholders] übergeben,
/// genau dafür. Das Öffnen läuft über die Naht [DateiOeffner.oeffne] — ein
/// Widget-Test darf keinen `rundll32`-Prozess starten.
void main() {
  const pfad = r'C:\Kanzlei\Vorlagen\VORLAGE Anspruchsschreiben HGn.docx';

  late List<String> geoeffnet;
  late int gewaehlt;
  late int entfernt;

  setUp(() {
    geoeffnet = [];
    gewaehlt = 0;
    entfernt = 0;
    DateiOeffner.oeffne = (pfad) async {
      geoeffnet.add(pfad);
      return true;
    };
    addTearDown(DateiOeffner.zuruecksetzen);
  });

  Future<void> zeige(
    WidgetTester tester, {
    String? pfad,
    SlotPlaceholders zustand = const SlotPlaceholdersInitial(),
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 460,
              child: VorlagenDateiKachel(
                slot: TemplateFileSlot.ohneAuflistung,
                titel: 'Ohne Schadensaufstellung (HGn)',
                erklaerung: 'Anspruchsschreiben ohne Positionsliste',
                pfad: pfad,
                zustand: zustand,
                onWaehlen: () => gewaehlt++,
                onEntfernen: () => entfernt++,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder knopf(String aufschrift) =>
      find.widgetWithText(CustomRectangularButton, aufschrift);

  testWidgets('ohne Datei steht die Wahl und sonst nichts', (tester) async {
    await zeige(tester);

    expect(find.text('Ohne Schadensaufstellung (HGn)'), findsOneWidget);
    expect(find.text('Anspruchsschreiben ohne Positionsliste'), findsOneWidget);
    expect(find.text('Noch keine Datei gewählt'), findsOneWidget);

    // Was es ohne Datei nicht zu tun gibt, steht auch nicht da.
    expect(knopf('In Word öffnen'), findsNothing);
    expect(knopf('Andere Datei wählen'), findsNothing);
    expect(find.byTooltip('Verknüpfung entfernen'), findsNothing);

    await tester.tap(knopf('Datei wählen…'));
    expect(gewaehlt, 1);
  });

  testWidgets('mit Datei stehen Dateiname und die drei Handlungen', (
    tester,
  ) async {
    await zeige(
      tester,
      pfad: pfad,
      zustand: const SlotPlaceholdersLoaded(['Mandant', 'Frist']),
    );

    // Nur der Dateiname; der Pfad gehört in den Tooltip, sonst erkennt
    // niemand mehr, welches Dokument das ist.
    expect(find.text('VORLAGE Anspruchsschreiben HGn.docx'), findsOneWidget);
    expect(find.text(pfad), findsNothing);
    expect(find.byTooltip(pfad), findsOneWidget);

    expect(find.text('2 Platzhalter erkannt'), findsOneWidget);
    expect(find.text('Noch keine Datei gewählt'), findsNothing);

    expect(knopf('In Word öffnen'), findsOneWidget);
    expect(knopf('Andere Datei wählen'), findsOneWidget);
    expect(find.byTooltip('Verknüpfung entfernen'), findsOneWidget);
    // „Datei wählen…" heißt jetzt „Andere Datei wählen" — dieselbe Handlung.
    expect(knopf('Datei wählen…'), findsNothing);

    await tester.tap(knopf('Andere Datei wählen'));
    await tester.tap(find.byTooltip('Verknüpfung entfernen'));
    expect(gewaehlt, 1);
    expect(entfernt, 1);
  });

  testWidgets('der Lesezustand steht in der Kachel', (tester) async {
    await zeige(tester, pfad: pfad, zustand: const SlotPlaceholdersLoading());
    expect(find.text('Platzhalter werden gelesen …'), findsOneWidget);

    await zeige(
      tester,
      pfad: pfad,
      zustand: const SlotPlaceholdersError('Die Datei ist in Word geöffnet.'),
    );
    expect(find.text('Die Datei ist in Word geöffnet.'), findsOneWidget);

    // Eine Datei ohne {{…}} ist kein Fehler, aber auch keine Zahl, die man
    // vorliest.
    await zeige(tester, pfad: pfad, zustand: const SlotPlaceholdersLoaded([]));
    expect(find.text('Keine Platzhalter erkannt'), findsOneWidget);
  });

  testWidgets('„In Word öffnen" reicht den Pfad an den Öffner', (tester) async {
    await zeige(
      tester,
      pfad: pfad,
      zustand: const SlotPlaceholdersLoaded(['Mandant']),
    );

    await tester.tap(knopf('In Word öffnen'));
    await tester.pumpAndSettle();

    expect(geoeffnet, [pfad]);
  });

  testWidgets('eine verschwundene Datei wird gemeldet, nicht verschluckt', (
    tester,
  ) async {
    // Der Pfad steht in der Vorlage, die Datei liegt nicht mehr dort — der
    // häufige Fall nach einem Umzug der Kanzleiablage.
    DateiOeffner.oeffne = (_) async => false;

    await zeige(
      tester,
      pfad: pfad,
      zustand: const SlotPlaceholdersLoaded(['Mandant']),
    );

    await tester.tap(knopf('In Word öffnen'));
    await tester.pumpAndSettle();

    // Der Dateiname, nicht der Pfad: Daran erkennt der Anwalt, welche der
    // beiden Dateien gemeint ist.
    expect(
      find.text(
        'Die Datei wurde nicht gefunden: '
        'VORLAGE Anspruchsschreiben HGn.docx',
      ),
      findsOneWidget,
    );
  });
}
