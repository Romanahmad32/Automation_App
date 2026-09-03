import 'package:automation_app/features/word_automation/presentation/utils/betrag_eingabe.dart';
import 'package:automation_app/features/word_automation/presentation/utils/rvg_felder_pruefung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schadensaufstellung_schritt.dart';

/// Die drei Felder unter der Positionsliste: Gebührensatz, „Geschäftsgebühr
/// überschreiben", „Auslagenpauschale überschreiben".
///
/// Sie scheiterten bis hierher so, wie es bei den Positionsbeträgen längst
/// abgeschafft ist — als unspezifischer HTTP 400 über einer Aufstellung, die
/// plausibel aussieht, ohne dass ein Feld markiert war. Der schärfste Fall ist
/// die `0` im Gebührensatz: Sie ist lesbar, der Rückfall auf 1,3 griff also
/// nicht, und `gebuehrensatz: 0` ging still hinaus.
///
/// Der Betrag je Position steht in `schadensposition_betrag_test.dart`.
void main() {
  final schritt = SchadensaufstellungSchritt();

  tearDown(schritt.schliesse);

  /// Gesucht wird über den Beschriftungstext, nicht über die Position im Baum:
  /// Vor dem Gebührensatz stehen zwei Felder je Standardposition, und die
  /// beiden Korrekturfelder liegen in der zugeklappten `ExpansionTile` darunter
  /// — sie sind erst nach [klappeKorrekturAuf] überhaupt im Baum.
  Finder gebuehrensatzfeld() => find.widgetWithText(
    TextField,
    '$gebuehrensatzFeldName (Geschäftsgebühr)',
  );
  Finder geschaeftsgebuehrfeld() =>
      find.widgetWithText(TextField, '$geschaeftsgebuehrFeldName (€)');
  Finder auslagenpauschalefeld() =>
      find.widgetWithText(TextField, '$auslagenpauschaleFeldName (€)');

  /// Erfasst eine gültige Position, damit `schadensaufstellungIstErzeugbar`
  /// nicht schon an „keine Position" scheitert — sonst bewiese ein gesperrter
  /// Knopf nichts über das geprüfte Feld.
  Future<void> erfassePosition(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Reparaturkosten');
    await tester.enterText(find.byType(TextField).at(1), '5000');
    await beruhige(tester);
  }

  Future<void> tippe(WidgetTester tester, Finder feld, String eingabe) async {
    await tester.ensureVisible(feld);
    await tester.pumpAndSettle();
    await tester.enterText(feld, eingabe);
    await beruhige(tester);
  }

  Future<void> klappeKorrekturAuf(WidgetTester tester) async {
    await tester.ensureVisible(find.text('RVG-Berechnung korrigieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RVG-Berechnung korrigieren'));
    await tester.pumpAndSettle();
  }

  testWidgets('0 im Gebührensatz sperrt das Erzeugen und markiert das Feld', (
    tester,
  ) async {
    await schritt.zeige(tester);
    await erfassePosition(tester);
    expect(erstellenKnopf(tester).onPressed, isNotNull);

    await tippe(tester, gebuehrensatzfeld(), '0');

    // An der Zeile selbst …
    expect(find.text(gebuehrensatzBereichHinweis), findsOneWidget);
    // … und als Satz über dem Knopf, benannt wie das Feld.
    expect(
      find.text('$gebuehrensatzFeldName: $gebuehrensatzBereichHinweis'),
      findsOneWidget,
    );
    expect(erstellenKnopf(tester).onPressed, isNull);
  });

  testWidgets('ein Gebührensatz über 10 sperrt ebenso', (tester) async {
    await schritt.zeige(tester);
    await erfassePosition(tester);
    await tippe(tester, gebuehrensatzfeld(), '13');

    expect(find.text(gebuehrensatzBereichHinweis), findsOneWidget);
    expect(erstellenKnopf(tester).onPressed, isNull);
  });

  /// Der Rückfall ist für das **leere** Feld gemeint — dort bleibt er.
  testWidgets('ein leerer Gebührensatz fällt weiterhin auf 1,3 zurück', (
    tester,
  ) async {
    await schritt.zeige(tester);
    await erfassePosition(tester);
    await tippe(tester, gebuehrensatzfeld(), '');

    expect(find.text(gebuehrensatzBereichHinweis), findsNothing);
    expect(
      schritt.umgebung.wizard.state.damageListing?.gebuehrensatz,
      gebuehrensatzVorgabe,
    );
    expect(erstellenKnopf(tester).onPressed, isNotNull);
  });

  /// Der zweite Weg, auf dem 1,3 still hinausging: Steht etwas Unlesbares im
  /// Feld, sah der Anwalt seine Eingabe und bekam trotzdem den Vorgabesatz.
  testWidgets('ein unlesbarer Gebührensatz sperrt statt still 1,3 zu senden', (
    tester,
  ) async {
    await schritt.zeige(tester);
    await erfassePosition(tester);
    await tippe(tester, gebuehrensatzfeld(), 'eins Komma drei');

    expect(find.text(gebuehrensatzUnlesbarHinweis), findsOneWidget);
    expect(erstellenKnopf(tester).onPressed, isNull);
  });

  testWidgets('die Sperre fällt, sobald der Gebührensatz berichtigt ist', (
    tester,
  ) async {
    await schritt.zeige(tester);
    await erfassePosition(tester);
    await tippe(tester, gebuehrensatzfeld(), '0');
    expect(erstellenKnopf(tester).onPressed, isNull);

    await tippe(tester, gebuehrensatzfeld(), '1,3');

    expect(find.text(gebuehrensatzBereichHinweis), findsNothing);
    expect(schritt.umgebung.wizard.state.damageListing?.gebuehrensatz, 1.3);
    expect(erstellenKnopf(tester).onPressed, isNotNull);
  });

  testWidgets('eine negative Geschäftsgebühr sperrt und markiert das Feld', (
    tester,
  ) async {
    await schritt.zeige(tester);
    await erfassePosition(tester);
    await klappeKorrekturAuf(tester);
    await tippe(tester, geschaeftsgebuehrfeld(), '-500');

    expect(find.text(negativerKorrekturbetragHinweis), findsOneWidget);
    expect(
      find.text('$geschaeftsgebuehrFeldName: $negativerKorrekturbetragHinweis'),
      findsOneWidget,
    );
    expect(erstellenKnopf(tester).onPressed, isNull);
  });

  testWidgets('eine negative Auslagenpauschale sperrt ebenso', (tester) async {
    await schritt.zeige(tester);
    await erfassePosition(tester);
    await klappeKorrekturAuf(tester);
    await tippe(tester, auslagenpauschalefeld(), '-20');

    expect(
      find.text('$auslagenpauschaleFeldName: $negativerKorrekturbetragHinweis'),
      findsOneWidget,
    );
    expect(erstellenKnopf(tester).onPressed, isNull);
  });

  /// Der stille Zwilling des Gebührensatz-Rückfalls, eine Zeile tiefer: Ein
  /// unlesbares Korrekturfeld fiel auf „automatisch" zurück. Der Anwalt sah
  /// seinen eingetippten Betrag im Feld stehen und bekam im Schreiben die
  /// errechnete Gebühr.
  testWidgets('eine unlesbare Geschäftsgebühr sperrt statt still zu rechnen', (
    tester,
  ) async {
    const eingabe = '1.234,56 €';
    await schritt.zeige(tester);
    await erfassePosition(tester);
    await klappeKorrekturAuf(tester);
    await tippe(tester, geschaeftsgebuehrfeld(), eingabe);

    expect(find.text(unlesbarerBetragHinweis(eingabe)), findsOneWidget);
    expect(
      schritt.umgebung.wizard.state.damageListing?.geschaeftsgebuehrOverride,
      isNull,
    );
    expect(erstellenKnopf(tester).onPressed, isNull);
  });

  /// Leer heißt hier „automatisch nach § 13 RVG rechnen" und ist der Normalfall
  /// — er darf nicht als Verstoß gelten.
  testWidgets('leere Korrekturfelder bleiben unbeanstandet', (tester) async {
    await schritt.zeige(tester);
    await erfassePosition(tester);
    await klappeKorrekturAuf(tester);

    expect(find.text(negativerKorrekturbetragHinweis), findsNothing);
    expect(
      schritt.umgebung.wizard.state.damageListing?.geschaeftsgebuehrOverride,
      isNull,
    );
    expect(erstellenKnopf(tester).onPressed, isNotNull);
  });

  group('die Leseregel der drei Felder', () {
    test('der Gebührensatz kennt seine Grenzen aus dem Backend', () {
      expect(gebuehrensatzFehler(''), isNull);
      expect(gebuehrensatzFehler('   '), isNull);
      expect(gebuehrensatzFehler('1,3'), isNull);
      expect(gebuehrensatzFehler('0,1'), isNull);
      expect(gebuehrensatzFehler('10'), isNull);
      expect(gebuehrensatzFehler('0'), gebuehrensatzBereichHinweis);
      expect(gebuehrensatzFehler('0,09'), gebuehrensatzBereichHinweis);
      expect(gebuehrensatzFehler('-1,3'), gebuehrensatzBereichHinweis);
      expect(gebuehrensatzFehler('10,1'), gebuehrensatzBereichHinweis);
      expect(gebuehrensatzFehler('abc'), gebuehrensatzUnlesbarHinweis);
    });

    /// Eine gültige Eingabe kommt nie durch einen unlesbaren Zwischenstand —
    /// sonst wäre die Markierung beim Tippen im Weg statt hilfreich.
    test('während des Tippens von 1,3 wird nichts markiert', () {
      for (final zwischenstand in ['1', '1,', '1,3']) {
        expect(
          gebuehrensatzFehler(zwischenstand),
          isNull,
          reason: zwischenstand,
        );
      }
    });

    test('die Korrekturfelder beanstanden Negatives und zu Großes', () {
      expect(korrekturbetragFehler(''), isNull);
      expect(korrekturbetragFehler('   '), isNull);
      expect(korrekturbetragFehler('0'), isNull);
      expect(korrekturbetragFehler('1.234,56'), isNull);
      expect(
        korrekturbetragFehler('1.234,56 €'),
        unlesbarerBetragHinweis('1.234,56 €'),
      );
      expect(korrekturbetragFehler('-0,01'), negativerKorrekturbetragHinweis);
      expect(korrekturbetragFehler('-500'), negativerKorrekturbetragHinweis);
      expect(
        korrekturbetragFehler('10000000,01'),
        zuGrosserKorrekturbetragHinweis,
      );
    });

    /// Der Rückfall gilt nur dort, wo er gemeint war. Unlesbares geht zwar
    /// weiterhin als 1,3 hinaus (die Aufstellung braucht eine Zahl), aber
    /// [gebuehrensatzFehler] sperrt dann das Erzeugen.
    test('der Rückfall auf 1,3 gilt dem leeren Feld', () {
      expect(gebuehrensatzAusEingabe(''), gebuehrensatzVorgabe);
      expect(gebuehrensatzAusEingabe('2,0'), 2.0);
      expect(gebuehrensatzAusEingabe('0'), 0.0);
    });

    test('die Sammelmeldung benennt jedes Feld einzeln', () {
      expect(
        rvgFelderFehler(
          gebuehrensatz: '0',
          geschaeftsgebuehr: '-500',
          auslagenpauschale: '',
        ),
        [
          '$gebuehrensatzFeldName: $gebuehrensatzBereichHinweis',
          '$geschaeftsgebuehrFeldName: $negativerKorrekturbetragHinweis',
        ],
      );
      expect(
        rvgFelderFehler(
          gebuehrensatz: '1,3',
          geschaeftsgebuehr: '',
          auslagenpauschale: '20',
        ),
        isEmpty,
      );
    });
  });
}
