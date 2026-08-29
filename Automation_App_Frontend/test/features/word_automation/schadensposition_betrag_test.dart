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

/// Der Betrag einer Schadensposition: `0,00` gehört ins Schreiben, ein
/// negativer Betrag nicht.
///
/// Beides endete vorher gleich — als HTTP 400 aus der Modellvalidierung des
/// Dienstes, ohne zu sagen, welche Zeile schuld ist. Das ist die schlechteste
/// Form der Rückmeldung: spät, unspezifisch, und die Zwischensumme darüber
/// sieht dabei völlig plausibel aus. Geprüft wird deshalb hier, im Formular,
/// an der Zeile.
class _FakeUpdateFormTemplate
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  @override
  Future<Either<Failure, FormTemplate>> call(UpdateFormTemplateParams params) =>
      throw UnimplementedError();
}

class _FakeGetMandanten implements UseCase<List<Mandant>, NoParams> {
  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async =>
      Right([]);
}

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
  late WizardCubit wizard;
  late DocumentBloc document;

  /// Baut den Schritt mit allem, was `canGenerate` braucht: ausgefülltes
  /// Formular aus Schritt 1 und eine geladene Vorlagendatei. Fehlte eines von
  /// beiden, wäre der Knopf ohnehin gesperrt und der Test bewiese nichts.
  Future<void> zeigeSchritt(WidgetTester tester) async {
    wizard = WizardCubit(_FakeUpdateFormTemplate(), _FakeGetMandanten());
    wizard.setFormData({'Name': 'Mustermann'});
    document = DocumentBloc(_FakeVorlagenUebersicht());
    document.add(const SetDocumentPathEvent(r'C:\Vorlagen\HGN.docx'));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: wizard),
          BlocProvider.value(value: document),
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
    expect(wizard.state.damageListing?.items.single.amount, 0);
    expect(erstellenKnopf(tester).onPressed, isNotNull);
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

  test('die Meldung nummeriert die Positionen wie die Vorschau', () {
    final fehler = schadenspositionenFehler(const [
      DamageItem(description: 'Reparaturkosten', amount: 2560.87),
      DamageItem(description: 'Gutachten', amount: 0),
      DamageItem(description: 'Bereits reguliert', amount: -500),
    ]);

    expect(fehler, [
      'Position 3 ("Bereits reguliert"): $negativerBetragHinweis',
    ]);
  });
}
