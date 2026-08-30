import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart';
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart';
import 'package:automation_app/features/word_automation/domain/usecases/calculate_rvg_fees.dart';
import 'package:automation_app/features/word_automation/domain/usecases/fill_out_template.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/schadenspositionen_pruefung.dart';
import 'package:automation_app/features/word_automation/presentation/views/wizard_step_schadensaufstellung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

/// Der Betrag einer Schadensposition: `0,00` gehört ins Schreiben, ein
/// negativer Betrag nicht.
///
/// Beides endete vorher gleich — als HTTP 400 aus der Modellvalidierung des
/// Dienstes, ohne zu sagen, welche Zeile schuld ist. Das ist die schlechteste
/// Form der Rückmeldung: spät, unspezifisch, und die Zwischensumme darüber
/// sieht dabei völlig plausibel aus. Geprüft wird deshalb hier, im Formular,
/// an der Zeile.
class _FakeVorlagenUebersicht implements UseCase<VorlagenUebersicht, NoParams> {
  @override
  Future<Either<Failure, VorlagenUebersicht>> call(NoParams params) =>
      throw UnimplementedError();
}

class _FakeFillOutTemplate
    implements UseCase<GeneratedDocument, FillOutTemplateParams> {
  @override
  Future<Either<Failure, GeneratedDocument>> call(
    FillOutTemplateParams params,
  ) => throw UnimplementedError();
}

/// Antwortet mit einer festen Berechnung — die Zahlen prüft der Backend-Test
/// (`RvgFeeCalculatorTests`), hier zählt nur, dass die Vorschau nicht hängt.
class _FakeCalculateRvgFees
    implements UseCase<RvgCalculation, CalculateRvgFeesParams> {
  @override
  Future<Either<Failure, RvgCalculation>> call(
    CalculateRvgFeesParams params,
  ) async => Right(
    const RvgCalculation(
      gegenstandswert: 0,
      gebuehrensatz: 1.3,
      wertgebuehr: 51.50,
      geschaeftsgebuehr: 66.95,
      auslagenpauschale: 13.39,
      netto: 80.34,
      umsatzsteuer: 0,
      brutto: 80.34,
    ),
  );
}

class _NieAbgerufeneSettings implements UseCase<KanzleiSettings, NoParams> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) =>
      throw UnimplementedError();
}

class _NieGespeicherteSettings
    implements UseCase<KanzleiSettings, KanzleiSettings> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(KanzleiSettings params) =>
      throw UnimplementedError();
}

void main() {
  WizardUmgebung? wizard;
  DocumentBloc? document;

  // Diese beiden gehen als BlocProvider.value in den Baum; deren Vertrag lässt
  // die Lebensdauer beim Aufrufer — anders als bei BlocProvider(create:), das
  // seine Blocs selbst schliesst. Ohne dieses tearDown blieben acht
  // StreamController über die Datei offen, und sobald einer dieser Blocs einmal
  // einen Timer startet, schlägt er in einem *anderen* Test als „A Timer is
  // still pending" auf.
  tearDown(() async {
    await wizard?.schliesse();
    await document?.close();
    wizard = null;
    document = null;
  });

  /// Baut den Schritt mit allem, was `canGenerate` braucht: ausgefülltes
  /// Formular aus Schritt 1 und eine geladene Vorlagendatei. Fehlte eines von
  /// beiden, wäre der Knopf ohnehin gesperrt und der Test bewiese nichts.
  Future<void> zeigeSchritt(WidgetTester tester) async {
    final umgebung = WizardUmgebung();
    final cubit = umgebung.wizard;
    cubit.setFormData({'Name': 'Mustermann'});
    final dokument = DocumentBloc(_FakeVorlagenUebersicht());
    dokument.add(const SetDocumentPathEvent(r'C:\Vorlagen\HGN.docx'));
    wizard = umgebung;
    document = dokument;

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: dokument),
          BlocProvider(
            create: (_) => EditedDocumentBloc(_FakeFillOutTemplate()),
          ),
          BlocProvider(
            create: (_) => RvgCalculationBloc(_FakeCalculateRvgFees()),
          ),
          BlocProvider(
            create: (_) => KanzleiSettingsBloc(
              _NieAbgerufeneSettings(),
              _NieGespeicherteSettings(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WizardStepSchadensaufstellung()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Wartet die Entprellung des [RvgCalculationBloc] (350 ms) ab. `pumpAndSettle`
  /// allein reicht dafür **nicht**: Ein wartender Timer plant kein Bild ein, die
  /// Schleife hält ihn also für erledigt — und der Test fällt am Ende über
  /// „A Timer is still pending".
  Future<void> beruhige(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> tippeBetrag(WidgetTester tester, String betrag) async {
    await tester.enterText(find.byType(TextField).at(1), betrag);
    await beruhige(tester);
  }

  Future<void> erfasse(
    WidgetTester tester, {
    required String bezeichnung,
    required String betrag,
  }) async {
    await tester.enterText(find.byType(TextField).at(0), bezeichnung);
    await tippeBetrag(tester, betrag);
  }

  CustomRectangularButton erstellenKnopf(WidgetTester tester) => tester
      .widgetList<CustomRectangularButton>(find.byType(CustomRectangularButton))
      .firstWhere(
        (knopf) =>
            knopf.label is Text &&
            (knopf.label as Text).data == 'Dokument erstellen',
      );

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
    expect(wizard!.wizard.state.damageListing?.items.single.amount, 0);
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

    final betrag = wizard!.wizard.state.damageListing!.items.single.amount;
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

    await tester.tap(find.widgetWithText(TextButton, 'Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), '-250');
    await beruhige(tester);

    expect(find.text(negativerBetragHinweis), findsOneWidget);
    expect(
      find.text('Position 2 ($ohneBezeichnung): $negativerBetragHinweis'),
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
    await tester.tap(find.widgetWithText(TextButton, 'Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), '-250');
    await beruhige(tester);
    expect(erstellenKnopf(tester).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Ändern'));
    await beruhige(tester);

    expect(
      find.text('Position 2 ($ohneBezeichnung): $negativerBetragHinweis'),
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
