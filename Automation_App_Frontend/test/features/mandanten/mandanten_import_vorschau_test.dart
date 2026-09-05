import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_aehnlichkeits_hinweis.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_ordner_auswahl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'import_testaufbau.dart';
import 'mandanten_testaufbau.dart';

/// Die beiden Sicherungen, die zwischen Vorschau und Register stehen:
///
/// * Ordnernamen, die es nicht gibt, halten die Übernahme auf — sie kommen aus
///   einem Programm, das welche erfinden kann.
/// * Ein ähnlicher Name im Register wird gezeigt, bevor daraus eine Dublette
///   wird.
///
/// Beides ist ein Weg über mehrere Bausteine (Cubit → Ansicht → Dialog →
/// zurück in die Datei), den kein Test einer einzelnen Klasse sieht.
void main() {
  /// Die Vorschau ist eine ganze Seite: Kopfzeile, Zusammenfassung, Band,
  /// Filterleiste und Liste. Auf den 800×600 der Voreinstellung fiele die
  /// halbe Liste unter den Rand, und die Tests prüften dann nur noch, was
  /// zufällig sichtbar war.
  void grosserBildschirm(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// Zwei Zeilen mit erfundenen Ordnern, eine mit einem wirklich vorhandenen.
  ImportTestaufbau mitUnbekanntenOrdnern() => ImportTestaufbau(
    inhalt: const MandantenImportDatei(
      mandanten: [
        ImportMandantEintrag(
          vorname: 'Mark',
          nachname: 'Schmidt',
          aktenOrdnernamen: ['VUnfallursache Erfunden'],
        ),
        ImportMandantEintrag(
          vorname: 'Eva',
          nachname: 'Klein',
          aktenOrdnernamen: ['VUnfallursache Klein'],
        ),
        ImportMandantEintrag(
          vorname: 'Anna',
          nachname: 'Meier',
          aktenOrdnernamen: ['Ordner ohne Entsprechung'],
        ),
      ],
    ),
    antwort: bericht(
      eintraege: [
        eintrag(0, name: 'Mark Schmidt'),
        eintrag(1, name: 'Eva Klein'),
        eintrag(2, name: 'Anna Meier'),
      ],
      neu: 3,
      ordnerZugeordnet: 3,
    ),
    ordner: const ['VUnfallursache Klein'],
  );

  testWidgets('das Band nennt die Zeilen mit unbekanntem Ordner', (
    tester,
  ) async {
    final aufbau = mitUnbekanntenOrdnern();
    grosserBildschirm(tester);
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(importSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    expect(
      find.text('2 Zeilen nennen Ordner, die es im Stammordner nicht gibt.'),
      findsOneWidget,
    );

    final knopf = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Übernehmen'),
    );
    expect(
      knopf.onPressed,
      isNull,
      reason: 'geschrieben wird nichts, solange ein Ordner ins Leere zeigt',
    );
  });

  testWidgets('ein Klick auf das Band filtert auf genau diese Zeilen', (
    tester,
  ) async {
    final aufbau = mitUnbekanntenOrdnern();
    grosserBildschirm(tester);
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(importSeite(aufbau.cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zeilen zeigen'));
    await tester.pumpAndSettle();

    expect(find.text('2 von 3 Zeilen in dieser Ansicht'), findsOneWidget);
    expect(find.text('Mark Schmidt'), findsOneWidget);
    expect(find.text('Anna Meier'), findsOneWidget);
    expect(find.text('Eva Klein'), findsNothing);
  });

  testWidgets('die betroffene Zeile ist in der Liste markiert', (tester) async {
    final aufbau = mitUnbekanntenOrdnern();
    grosserBildschirm(tester);
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(importSeite(aufbau.cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle (3)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nennt einen Ordner, den es im Stammordner nicht gibt.'),
      findsNWidgets(2),
    );
  });

  testWidgets('mit Scan werden Ordner ausgewählt statt getippt', (
    tester,
  ) async {
    final aufbau = mitUnbekanntenOrdnern();
    grosserBildschirm(tester);
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(importSeite(aufbau.cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle (3)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    expect(find.byType(ImportOrdnerAuswahl), findsOneWidget);
    expect(find.byType(Autocomplete<String>), findsOneWidget);

    await tester.enterText(
      find.ancestor(
        of: find.text('Akten-Ordner'),
        matching: find.byType(TextField),
      ),
      'Klein',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('VUnfallursache Klein'),
      findsWidgets,
      reason: 'der gescannte Ordner wird als Vorschlag angeboten',
    );
  });

  // Der Kern des Ähnlichkeitshinweises: „Schmitt" gegen „Schmidt" ist für den
  // Dienst ein neuer Mandant, für einen Menschen offensichtlich derselbe.
  testWidgets('„Übernehmen" macht aus der neuen Zeile eine ergänzte', (
    tester,
  ) async {
    final aufbau = ImportTestaufbau(
      inhalt: const MandantenImportDatei(
        mandanten: [
          ImportMandantEintrag(
            vorname: 'Mark',
            nachname: 'Schmitt',
            aktenOrdnernamen: ['VUnfallursache Schmitt'],
            quelle: 'Schmitt/Schreiben.docx',
            sicherheit: 'mittel',
          ),
        ],
      ),
      berichtVon: (datei) {
        // Wie der Dienst: gleicher Name im Register heißt „ergänzt", sonst
        // „neu". Eine feste Antwort bemerkte die Berichtigung gar nicht.
        final trifft = datei.mandanten.single.nachname == 'Schmidt';
        return bericht(
          eintraege: [
            eintrag(
              0,
              name: datei.mandanten.single.anzeigename,
              art: trifft ? ImportArt.ergaenzt : ImportArt.neu,
            ),
          ],
          neu: trifft ? 0 : 1,
          ergaenzt: trifft ? 1 : 0,
          ordnerZugeordnet: 1,
        );
      },
      register: [mandant(7, 'Schmidt', vorname: 'Mark')],
    );
    grosserBildschirm(tester);
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();
    expect(aufbau.cubit.state.bericht?.eintraege.single.art, ImportArt.neu);

    await tester.pumpWidget(importSeite(aufbau.cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle (1)'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ähnlicher Name im Register — beim Bearbeiten prüfen.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(ImportAehnlichkeitsHinweis), findsOneWidget);
    expect(find.text('Ähnlicher Name im Register'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ImportAehnlichkeitsHinweis),
        matching: find.widgetWithText(FilledButton, 'Übernehmen'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Änderung übernehmen'));
    await tester.pumpAndSettle();

    final geschickt = aufbau.importieren.gesendet.last.mandanten.single;
    expect(geschickt.nachname, 'Schmidt');
    expect(geschickt.vorname, 'Mark');
    expect(
      aufbau.cubit.state.bericht?.eintraege.single.art,
      ImportArt.ergaenzt,
    );
    expect(
      aufbau.importieren.schreibendeAufrufe,
      0,
      reason: 'geprüft, nicht geschrieben — der Haltepunkt bleibt',
    );
  });

  // Herkunft und Selbsteinschätzung beschreiben den Fund, nicht den Mandanten.
  // Auch eine Übernahme aus dem Register darf sie nicht überschreiben.
  testWidgets('die Übernahme lässt Quelle und Sicherheit stehen', (
    tester,
  ) async {
    final aufbau = ImportTestaufbau(
      inhalt: const MandantenImportDatei(
        mandanten: [
          ImportMandantEintrag(
            vorname: 'Mark',
            nachname: 'Schmitt',
            aktenOrdnernamen: ['VUnfallursache Schmitt'],
            quelle: 'Schmitt/Schreiben.docx',
            sicherheit: 'mittel',
          ),
        ],
      ),
      antwort: bericht(
        eintraege: [eintrag(0, name: 'Mark Schmitt')],
        neu: 1,
        ordnerZugeordnet: 1,
      ),
      register: [mandant(7, 'Schmidt', vorname: 'Mark')],
    );
    grosserBildschirm(tester);
    addTearDown(aufbau.close);
    await aufbau.geoeffnet();

    await tester.pumpWidget(importSeite(aufbau.cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(ImportAehnlichkeitsHinweis),
        matching: find.widgetWithText(FilledButton, 'Übernehmen'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Änderung übernehmen'));
    await tester.pumpAndSettle();

    final geschickt = aufbau.importieren.gesendet.last.mandanten.single;
    expect(geschickt.quelle, 'Schmitt/Schreiben.docx');
    expect(geschickt.sicherheit, 'mittel');
    expect(geschickt.aktenOrdnernamen, ['VUnfallursache Schmitt']);
    expect(geschickt.bearbeitet, isTrue);
  });
}
