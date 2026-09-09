import 'package:automation_app/features/register_import/presentation/widgets/register_import_datei_auswahl.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_zeile_kachel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'register_import_testaufbau.dart';

void main() {
  testWidgets('ohne Datei steht die Erklärung und die Auswahl', (tester) async {
    final aufbau = RegisterImportTestaufbau();
    addTearDown(aufbau.close);

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));

    expect(find.byType(RegisterImportDateiAuswahl), findsOneWidget);
    expect(find.text('JSON-Datei wählen'), findsOneWidget);
    expect(find.text('Auftrag für den Erzeuger'), findsOneWidget);
  });

  // Die eine Fehlerklasse, die kein Erzeuger an sich selbst bemerkt: eine
  // verlorene Zeile. „3 Lücken" ist eine Zahl, „fehlt: 2, 5" ist ein Auftrag.
  testWidgets('die Befundkarte nennt die fehlenden Nummern', (tester) async {
    final aufbau = RegisterImportTestaufbau(
      inhalt: registerDatei(zeilen: [zeile(1), zeile(3), zeile(4), zeile(6)]),
    );
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    expect(find.text('Jahrgang 2022 — 4 Zeilen'), findsOneWidget);
    expect(find.text('Fehlende Nummern: 2, 5'), findsOneWidget);
  });

  testWidgets('der Filter zeigt zuerst nur die zu prüfenden Zeilen', (
    tester,
  ) async {
    final aufbau = RegisterImportTestaufbau(
      inhalt: registerDatei(
        zeilen: [
          zeile(1),
          zeile(2, sicherheit: 'niedrig'),
          zeile(3),
          zeile(4, spalte1: '9'),
        ],
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    expect(find.text('nur zu prüfen (2)'), findsOneWidget);
    expect(find.byType(RegisterImportZeileKachel), findsNWidgets(2));

    await tester.tap(find.text('nur zu prüfen (2)'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterImportZeileKachel), findsNWidgets(4));
  });

  testWidgets('eine unsichere Zeile trägt ihr Wort und ihren Befund', (
    tester,
  ) async {
    final aufbau = RegisterImportTestaufbau(
      inhalt: registerDatei(zeilen: [zeile(4, spalte1: '9')]),
    );
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    expect(
      find.text('Spalte 1 „9" widerspricht der Nummer 4.'),
      findsOneWidget,
    );
    expect(find.text('Max Mustermann ./. HUK'), findsOneWidget);
  });

  // Der Weg vom Bericht in den Dialog und zurück in die Datei — die Stelle,
  // die kein Cubit-Test sieht.
  // Review: derselbe Wortlaut wie im Mandanten-Import — zwei Wortleitern für
  // dieselbe Selbsteinschätzung liefen sonst auseinander.
  testWidgets('die Sicherheitsstufe steht ausgeschrieben als Chip', (
    tester,
  ) async {
    final aufbau = RegisterImportTestaufbau(
      inhalt: registerDatei(
        zeilen: [
          zeile(1, sicherheit: 'niedrig'),
          zeile(2, sicherheit: 'mittel'),
        ],
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    expect(find.text('sehr unsicher'), findsOneWidget);
    expect(find.text('unsicher'), findsOneWidget);
  });

  testWidgets('eine Zeile lässt sich im Dialog weglassen', (tester) async {
    final aufbau = RegisterImportTestaufbau(
      inhalt: registerDatei(
        zeilen: [
          zeile(1),
          zeile(2, sicherheit: 'niedrig'),
        ],
      ),
    );
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Nr. 2 / 2022 bearbeiten'), findsOneWidget);
    expect(
      find.textContaining('Im Register:'),
      findsOneWidget,
      reason: 'der Freitext ist der Beleg, gegen den geprüft wird',
    );

    await tester.tap(find.text('Zeile weglassen'));
    await tester.pumpAndSettle();

    final zeilen = aufbau.importieren.gesendet.last.jahrgaenge.single.zeilen;
    expect(zeilen.map((z) => z.laufendeNummer), [1]);
    expect(aufbau.importieren.schreibendeAufrufe, 0);
  });

  testWidgets('ein berichtigtes Rechtsgebiet landet in der Datei', (
    tester,
  ) async {
    final aufbau = RegisterImportTestaufbau(
      inhalt: registerDatei(zeilen: [zeile(1, sicherheit: 'mittel')]),
    );
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.ancestor(
        of: find.text('Rechtsgebiet'),
        matching: find.byType(TextField),
      ),
      'Verkehrsstrafrecht',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Änderung übernehmen'));
    await tester.pumpAndSettle();

    final geschickt =
        aufbau.importieren.gesendet.last.jahrgaenge.single.zeilen.single;
    expect(geschickt.rechtsgebiet, 'Verkehrsstrafrecht');
    expect(geschickt.bearbeitet, isTrue);
    expect(aufbau.importieren.schreibendeAufrufe, 0);
  });

  testWidgets('Übernehmen an der Karte fragt nach und schreibt erst danach', (
    tester,
  ) async {
    final aufbau = RegisterImportTestaufbau();
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen'));
    await tester.pumpAndSettle();
    expect(find.text('Jahrgang 2022 übernehmen?'), findsOneWidget);
    expect(aufbau.importieren.schreibendeAufrufe, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
    await tester.pumpAndSettle();
    expect(aufbau.importieren.schreibendeAufrufe, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Übernehmen').last);
    await tester.pumpAndSettle();

    expect(aufbau.importieren.schreibendeAufrufe, 1);
    expect(find.text('übernommen'), findsOneWidget);
  });

  testWidgets('nach der Übernahme ist keine Zeile mehr änderbar', (
    tester,
  ) async {
    final aufbau = RegisterImportTestaufbau();
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();
    await aufbau.cubit.uebernehmen(jahrgang: 2022);

    await tester.pumpWidget(registerImportSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    final knopf = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.edit_outlined),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(knopf.onPressed, isNull);
  });
}
