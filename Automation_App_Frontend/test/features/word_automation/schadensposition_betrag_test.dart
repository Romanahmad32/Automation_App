import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/utils/schadenspositionen_pruefung.dart';
import 'package:automation_app/features/word_automation/presentation/views/wizard_step_schadensaufstellung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schadensaufstellung_schritt.dart';

/// Der Betrag einer Schadensposition: `0,00` gehört ins Schreiben, ein
/// negativer Betrag nicht.
///
/// Beides endete vorher gleich — als HTTP 400 aus der Modellvalidierung des
/// Dienstes, ohne zu sagen, welche Zeile schuld ist. Das ist die schlechteste
/// Form der Rückmeldung: spät, unspezifisch, und die Zwischensumme darüber
/// sieht dabei völlig plausibel aus. Geprüft wird deshalb hier, im Formular,
/// an der Zeile.
///
/// Die drei Felder unter der Liste (Gebührensatz, die beiden Korrekturfelder)
/// prüft `rvg_felder_test.dart` — dieselbe Bahn, andere Eingaben.
void main() {
  final schritt = SchadensaufstellungSchritt();

  tearDown(schritt.schliesse);

  Future<void> zeigeSchritt(WidgetTester tester) => schritt.zeige(tester);

  Future<void> tippeBetrag(WidgetTester tester, String betrag) async {
    await tester.enterText(find.byType(TextField).at(1), betrag);
    await beruhige(tester);
  }

  /// Hängt über das „+"-Menü eine leere Zeile an — sie steht dann hinter den
  /// Standardpositionen, mit denen das Formular anfängt (§4.4).
  ///
  /// `ensureVisible` ist nötig, weil die fünf Standardpositionen das Menü in
  /// der 450 Pixel breiten Spalte unter den sichtbaren Bereich schieben; ein
  /// `tap` darauf träfe ins Leere.
  Future<void> haengeLeereZeileAn(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leere Position'));
    await tester.pumpAndSettle();
  }

  /// Die Nummer dieser angehängten Zeile — im Formular von oben gezählt, so wie
  /// der Anwalt sie sieht, und so wie die Beanstandung sie benennt.
  final angehaengteZeile = StandardSchadenspositionen.bezeichnungen.length;

  Finder betragsfeld(int zeile) => find.byType(TextField).at(zeile * 2 + 1);

  Future<void> erfasse(
    WidgetTester tester, {
    required String bezeichnung,
    required String betrag,
  }) async {
    await tester.enterText(find.byType(TextField).at(0), bezeichnung);
    await tippeBetrag(tester, betrag);
  }

  testWidgets(
    'ein negativer Betrag sperrt das Erzeugen und benennt die Zeile',
    (tester) async {
      await zeigeSchritt(tester);
      await erfasse(tester, bezeichnung: 'Wertminderung', betrag: '-250');

      // An der Zeile selbst …
      expect(find.text(negativerBetragHinweis), findsOneWidget);
      // … und als Satz über dem Knopf, mit der Nummer aus der Vorschau.
      expect(
        find.text('Position 1 ("Wertminderung"): $negativerBetragHinweis'),
        findsOneWidget,
      );
      expect(erstellenKnopf(tester).onPressed, isNull);
    },
  );

  testWidgets('eine Position mit 0,00 ist gültig und gibt den Knopf frei', (
    tester,
  ) async {
    await zeigeSchritt(tester);
    await erfasse(
      tester,
      bezeichnung: 'Sachverständigenkosten',
      betrag: '0,00',
    );

    expect(find.text(negativerBetragHinweis), findsNothing);
    expect(schritt.umgebung.wizard.state.damageListing?.items.single.amount, 0);
    expect(erstellenKnopf(tester).onPressed, isNotNull);
  });

  /// `-0,0` ist numerisch null und damit **kein** Verstoss — es darf aber auch
  /// nicht als `-0.0` in den Vertrag hinausgehen, sonst widerspricht der Stand
  /// wörtlich der Zusage „kein negativer Betrag". Achtung bei der Prüfung:
  /// `-0.0 == 0` ist in Dart `true`, ein `expect(..., 0)` liefe also auch bei
  /// `-0.0` durch. Nur `isNegative` trennt die beiden.
  testWidgets('ein Betrag von -0,00 verlässt das Formular als 0,0', (
    tester,
  ) async {
    await zeigeSchritt(tester);
    await erfasse(tester, bezeichnung: 'Gutachten', betrag: '-0,00');

    final betrag =
        schritt.umgebung.wizard.state.damageListing!.items.single.amount;
    expect(betrag.isNegative, isFalse);
    expect(find.text(negativerBetragHinweis), findsNothing);
    expect(erstellenKnopf(tester).onPressed, isNotNull);
  });

  /// Der Fall, den die erste Fassung durchgehen liess: Eine Zeile ohne
  /// Bezeichnung wandert nicht in die Aufstellung. Wer die Beanstandungen aus
  /// der fertigen Aufstellung ableitet, sieht sie deshalb nie — das Feld war
  /// sichtbar rot und der Knopf trotzdem frei.
  testWidgets('eine negative Zeile ohne Bezeichnung sperrt trotzdem', (
    tester,
  ) async {
    await zeigeSchritt(tester);
    await erfasse(tester, bezeichnung: 'Reparaturkosten', betrag: '500');
    expect(erstellenKnopf(tester).onPressed, isNotNull);

    await haengeLeereZeileAn(tester);
    await tester.enterText(betragsfeld(angehaengteZeile), '-250');
    await beruhige(tester);

    expect(find.text(negativerBetragHinweis), findsOneWidget);
    expect(
      find.text(
        'Position ${angehaengteZeile + 1} '
        '($ohneBezeichnung): $negativerBetragHinweis',
      ),
      findsOneWidget,
    );
    expect(erstellenKnopf(tester).onPressed, isNull);
  });

  /// Das Umschalten der Vorsteuer rechnet die Aufstellung neu — dabei dürfen die
  /// Beanstandungen nicht verlorengehen. Sie aus `listing.items` neu abzuleiten
  /// tut aber genau das: Die beanstandete Zeile ohne Bezeichnung steht da gar
  /// nicht drin. Ergebnis wäre ein rotes Feld über einem freigegebenen Knopf.
  testWidgets('das Umschalten der Vorsteuer hebt die Sperre nicht auf', (
    tester,
  ) async {
    await zeigeSchritt(tester);
    await erfasse(tester, bezeichnung: 'Reparaturkosten', betrag: '500');
    await haengeLeereZeileAn(tester);
    await tester.enterText(betragsfeld(angehaengteZeile), '-250');
    await beruhige(tester);
    expect(erstellenKnopf(tester).onPressed, isNull);

    // Die Vorsteuer-Karte steht über der Aufstellung; das Anhängen der Zeile
    // hat die Spalte nach unten gescrollt.
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ändern'));
    await beruhige(tester);

    expect(
      find.text(
        'Position ${angehaengteZeile + 1} '
        '($ohneBezeichnung): $negativerBetragHinweis',
      ),
      findsOneWidget,
    );
    expect(erstellenKnopf(tester).onPressed, isNull);
  });

  /// Der Reset der Vorschau hängt daran, dass auch der leere Stand beim Bloc
  /// ankommt. Wird er unterdrückt, bleibt der zuletzt berechnete Betrag stehen
  /// und die Vorschau behauptet Anwaltskosten zu einer Aufstellung, die es
  /// nicht mehr gibt.
  testWidgets('ohne Position fällt die RVG-Vorschau auf den Anfang zurück', (
    tester,
  ) async {
    await zeigeSchritt(tester);
    await erfasse(tester, bezeichnung: 'Reparaturkosten', betrag: '5000');

    final rvg = tester
        .element(find.byType(WizardStepSchadensaufstellung))
        .read<RvgCalculationBloc>();
    expect(rvg.state, isA<RvgCalculationLoaded>());

    await tester.enterText(find.byType(TextField).at(0), '');
    await beruhige(tester);

    expect(rvg.state, isA<RvgCalculationInitial>());
  });

  testWidgets('die Sperre fällt, sobald der Betrag berichtigt ist', (
    tester,
  ) async {
    await zeigeSchritt(tester);
    await erfasse(tester, bezeichnung: 'Wertminderung', betrag: '-250');
    expect(erstellenKnopf(tester).onPressed, isNull);

    await tippeBetrag(tester, '250');

    expect(find.text(negativerBetragHinweis), findsNothing);
    expect(erstellenKnopf(tester).onPressed, isNotNull);
  });

  test('die Meldung zählt die Zeilen von oben und nennt die Bezeichnung', () {
    final fehler = schadenspositionenFehler(const [
      (bezeichnung: 'Reparaturkosten', betrag: 2560.87),
      (bezeichnung: 'Gutachten', betrag: 0.0),
      (bezeichnung: '', betrag: -500.0),
      (bezeichnung: 'Bereits reguliert', betrag: -500.0),
      (bezeichnung: 'noch nichts getippt', betrag: null),
    ]);

    expect(fehler, [
      'Position 3 ($ohneBezeichnung): $negativerBetragHinweis',
      'Position 4 ("Bereits reguliert"): $negativerBetragHinweis',
    ]);
  });

  test('positionenFehler prüft erfasste Positionen nach derselben Regel', () {
    expect(
      positionenFehler(const [
        DamageItem(description: 'Reparaturkosten', amount: 2560.87),
        DamageItem(description: 'Bereits reguliert', amount: -500),
      ]),
      ['Position 2 ("Bereits reguliert"): $negativerBetragHinweis'],
    );
  });
}
