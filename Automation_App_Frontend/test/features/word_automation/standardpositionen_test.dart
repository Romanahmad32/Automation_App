import 'dart:io';

import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/damage_listing_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Womit eine Schadensaufstellung anfängt (§4.4).
///
/// Vorher stand dort eine leere Zeile, und die immer gleichen fünf Positionen
/// wurden bei jedem Schreiben neu getippt — mit jeder Tippvariante, die dabei
/// entsteht. Geprüft wird deshalb dreierlei: dass die fünf da stehen, dass ein
/// gespeicherter Stand ihnen vorgeht, und dass eine Position ohne Betrag
/// wieder verschwindet, ohne dass jemand sie löschen muss.
void main() {
  /// Die Zeilen des Formulars stehen im Baum als Paare: Bezeichnung, Betrag.
  Finder bezeichnungsfeld(int zeile) => find.byType(TextField).at(zeile * 2);
  Finder betragsfeld(int zeile) => find.byType(TextField).at(zeile * 2 + 1);

  String textIn(WidgetTester tester, Finder feld) =>
      tester.widget<TextField>(feld).controller!.text;

  /// Wie viele Zeilen die Aufstellung gerade hat — abgeleitet aus den
  /// Löschknöpfen, denn genau einer steht an jeder Zeile.
  int zeilenzahl(WidgetTester tester) =>
      tester.widgetList(find.byTooltip('Position entfernen')).length;

  DamageListing? zuletztGemeldet;

  setUp(() => zuletztGemeldet = null);

  Future<void> zeigeFormular(
    WidgetTester tester, {
    DamageListing? gespeichert,
    List<StandardSchadensposition>? konfiguriert,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DamageListingForm(
              initialValue: gespeichert,
              standardpositionen:
                  konfiguriert ?? StandardSchadenspositionen.vorgabe,
              onChanged: (aufstellung, _) => zuletztGemeldet = aufstellung,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> waehleImMenue(WidgetTester tester, String eintrag) async {
    await tester.tap(find.byTooltip('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(eintrag).last);
    await tester.pumpAndSettle();
  }

  testWidgets('ohne gespeicherten Stand stehen die fünf üblichen Positionen '
      'da, alle Beträge leer', (tester) async {
    await zeigeFormular(tester);

    expect(zeilenzahl(tester), StandardSchadenspositionen.bezeichnungen.length);
    for (final (zeile, bezeichnung)
        in StandardSchadenspositionen.bezeichnungen.indexed) {
      expect(textIn(tester, bezeichnungsfeld(zeile)), bezeichnung);
      expect(textIn(tester, betragsfeld(zeile)), isEmpty);
    }
  });

  /// Der gespeicherte Stand ist erfasste Arbeit des Anwalts. Träten die
  /// Standardpositionen daneben oder davor, stünde beim Zurückblättern im
  /// Wizard plötzlich eine andere Aufstellung da als die abgeschickte.
  testWidgets('ein gespeicherter Stand gewinnt gegen die Standardpositionen', (
    tester,
  ) async {
    await zeigeFormular(
      tester,
      gespeichert: const DamageListing(
        items: [DamageItem(description: 'Mietwagenkosten', amount: 412.50)],
      ),
    );

    expect(zeilenzahl(tester), 1);
    expect(textIn(tester, bezeichnungsfeld(0)), 'Mietwagenkosten');
    expect(textIn(tester, betragsfeld(0)), '412,5');
    for (final bezeichnung in StandardSchadenspositionen.bezeichnungen) {
      expect(find.text(bezeichnung), findsNothing);
    }
  });

  /// Der Grund, warum die fünf Bezeichnungen ohne Betrag danebenstehen dürfen:
  /// Was der Fall nicht hergibt, wird gar nicht erst zur Position. Löschen muss
  /// deshalb niemand — im Dokument steht nur, was beziffert ist.
  testWidgets('eine Position ohne Betrag wandert nicht in die Aufstellung', (
    tester,
  ) async {
    await zeigeFormular(tester);
    await tester.enterText(betragsfeld(0), '2560,87');
    await tester.pumpAndSettle();

    expect(zeilenzahl(tester), StandardSchadenspositionen.bezeichnungen.length);
    expect(zuletztGemeldet!.items, [
      DamageItem(
        description: StandardSchadenspositionen.bezeichnungen.first,
        amount: 2560.87,
      ),
    ]);
  });

  /// Das „+"-Menü ist der Rückweg. Ohne ihn wäre eine gelöschte Standard-
  /// position nur durch Abtippen zurückzuholen — und beim Abtippen entsteht
  /// genau die Schreibvariante, gegen die die feste Liste steht.
  testWidgets('eine gelöschte Standardposition kommt über das Menü zurück', (
    tester,
  ) async {
    const wertminderung = 'Wertminderung nach Gutachten';
    await zeigeFormular(tester);
    await tester.tap(find.byTooltip('Position entfernen').at(1));
    await tester.pumpAndSettle();
    expect(find.text(wertminderung), findsNothing);

    await waehleImMenue(tester, wertminderung);

    expect(zeilenzahl(tester), StandardSchadenspositionen.bezeichnungen.length);
    expect(find.text(wertminderung), findsOneWidget);
  });

  /// Solange eine Standardposition dasteht, ist ihr Menüeintrag abgehakt und
  /// gesperrt: Der häufigste Griff — Menü auf, erste Zeile — legte sonst ein
  /// Doppel der Position an, die ohnehin schon da ist.
  testWidgets('vorhandene Positionen sind im Menü nicht noch einmal wählbar', (
    tester,
  ) async {
    await zeigeFormular(tester);
    await tester.tap(find.byTooltip('Position hinzufügen'));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.check),
      findsNWidgets(StandardSchadenspositionen.bezeichnungen.length),
    );
  });

  /// Überschreiben ist der zweite Weg, eine Standardposition loszuwerden — und
  /// der stillere: Das Formular baut sich dabei nicht neu auf. Wer den Satz der
  /// vorhandenen Bezeichnungen beim Aufbau einsammelt, hält die überschriebene
  /// Position weiter für vorhanden und sperrt den Rückweg.
  testWidgets('eine überschriebene Standardposition ist wieder wählbar', (
    tester,
  ) async {
    const unkostenpauschale = 'Unkostenpauschale';
    await zeigeFormular(tester);
    await tester.enterText(bezeichnungsfeld(2), 'Mietwagenkosten');
    await tester.pumpAndSettle();

    await waehleImMenue(tester, unkostenpauschale);

    // Die überschriebene Zeile bleibt stehen, die Position kommt daneben.
    expect(
      zeilenzahl(tester),
      StandardSchadenspositionen.bezeichnungen.length + 1,
    );
    expect(find.text(unkostenpauschale), findsOneWidget);
    expect(find.text('Mietwagenkosten'), findsOneWidget);
  });

  testWidgets('das Menü legt auf Wunsch weiter eine leere Zeile an', (
    tester,
  ) async {
    await zeigeFormular(tester);
    await waehleImMenue(tester, 'Leere Position');

    final letzte = StandardSchadenspositionen.bezeichnungen.length;
    expect(zeilenzahl(tester), letzte + 1);
    expect(textIn(tester, bezeichnungsfeld(letzte)), isEmpty);
  });

  /// In den Einstellungen konfigurierte Positionen ersetzen die Vorgabe —
  /// samt hinterlegtem Betrag, der nur vorbelegt und weiter änderbar ist.
  testWidgets('konfigurierte Positionen belegen Bezeichnung und Betrag vor', (
    tester,
  ) async {
    await zeigeFormular(
      tester,
      konfiguriert: const [
        StandardSchadensposition(bezeichnung: 'Mietwagenkosten', betrag: 412.5),
        StandardSchadensposition(bezeichnung: 'Unkostenpauschale'),
      ],
    );

    expect(zeilenzahl(tester), 2);
    expect(textIn(tester, bezeichnungsfeld(0)), 'Mietwagenkosten');
    expect(textIn(tester, betragsfeld(0)), '412,5');
    expect(textIn(tester, bezeichnungsfeld(1)), 'Unkostenpauschale');
    expect(textIn(tester, betragsfeld(1)), isEmpty);
  });

  /// Auch der Rückweg über das „+"-Menü bringt den konfigurierten Betrag mit:
  /// Die zurückgeholte Zeile sieht aus wie die ursprünglich vorbelegte.
  testWidgets('das Menü bietet die konfigurierten Positionen samt Betrag an', (
    tester,
  ) async {
    await zeigeFormular(
      tester,
      konfiguriert: const [
        StandardSchadensposition(bezeichnung: 'Mietwagenkosten', betrag: 412.5),
        StandardSchadensposition(bezeichnung: 'Unkostenpauschale', betrag: 30),
      ],
    );
    await tester.tap(find.byTooltip('Position entfernen').first);
    await tester.pumpAndSettle();

    await waehleImMenue(tester, 'Mietwagenkosten');

    expect(zeilenzahl(tester), 2);
    expect(textIn(tester, bezeichnungsfeld(1)), 'Mietwagenkosten');
    expect(textIn(tester, betragsfeld(1)), '412,5');
  });

  /// Die Liste ist eine fachliche Festlegung, keine Eigenheit der Maske. Wer
  /// sie im Code ändert, ohne die Anforderung zu ändern, bekommt hier einen
  /// roten Test — und nicht erst der Anwalt ein Schreiben mit einer Position,
  /// die so nie vereinbart war.
  test('Reihenfolge und Wortlaut stehen so in REQUIREMENTS.md §4.4', () {
    final anforderungen = File('../REQUIREMENTS.md');
    if (!anforderungen.existsSync()) {
      fail(
        '../REQUIREMENTS.md nicht gefunden — läuft der Test aus '
        'Automation_App_Frontend heraus?',
      );
    }

    // Erst den Abschnitt herausschneiden, dann darin suchen. Über das ganze
    // Dokument gesucht bliebe der Test grün, während die Aufzählung längst in
    // einem anderen Kapitel steht — und die Meldung behauptete weiter §4.4.
    final abschnitt = RegExp(
      r'### 4\.4 .*?(?=\n### )',
      dotAll: true,
    ).firstMatch(anforderungen.readAsStringSync());
    expect(abschnitt, isNotNull, reason: '§4.4 nicht in REQUIREMENTS.md');

    // Umbrüche und Einrückung wegnormalisieren: „Abschleppkosten /
    // Standgeldkosten" steht im Fließtext über zwei Zeilen.
    final text = abschnitt![0]!.replaceAll(RegExp(r'\s+'), ' ');
    final aufzaehlung = RegExp(
      r'Standardpositionen:\*\* (.*?)(?: - \*\*\[M\]\*\*|$)',
    ).firstMatch(text);
    expect(
      aufzaehlung,
      isNotNull,
      reason: 'In §4.4 steht kein Punkt „Standardpositionen".',
    );

    // Gleichheit, nicht bloss Vorkommen: Eine sechste Position in der
    // Anforderung, die im Code fehlt, muss hier genauso auffallen wie
    // umgekehrt. Ein reiner Vorkommenstest sähe nur eine der beiden Lücken.
    final genannt = [
      for (final treffer in RegExp('„([^"]+)"').allMatches(aufzaehlung![1]!))
        treffer.group(1)!,
    ];
    expect(
      genannt,
      StandardSchadenspositionen.bezeichnungen,
      reason:
          'Die Aufzählung in §4.4 und StandardSchadenspositionen sind '
          'auseinandergelaufen. Erst die Anforderung ändern, dann den Code.',
    );
  });
}
