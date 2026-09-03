/// Der Schadensaufstellungs-Schritt im Widget-Test, aufgebaut mit allem, was
/// `canGenerate` braucht: ausgefuelltes Formular aus Schritt 1 und eine
/// geladene Vorlagendatei. Fehlte eines von beiden, waere „Dokument erstellen"
/// ohnehin gesperrt und ein Test darueber bewiese nichts.
///
/// Eigene Datei, weil zwei Testdateien denselben Aufbau brauchen: die Pruefung
/// der Positionsbetraege (`schadensposition_betrag_test.dart`) und die der drei
/// RVG-Felder (`rvg_felder_test.dart`). Zwei Abschriften von sechs Blocs und
/// fuenf Fakes haetten irgendwann zwei Meinungen darueber, was der Schritt ist.
library;

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart';
import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart';
import 'package:automation_app/features/word_automation/domain/repositories/standard_schadenspositionen_repository.dart';
import 'package:automation_app/features/word_automation/domain/usecases/calculate_rvg_fees.dart';
import 'package:automation_app/features/word_automation/domain/usecases/fill_out_template.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/standardpositionen_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/views/wizard_step_schadensaufstellung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

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

/// Antwortet mit einer festen Berechnung — die Zahlen prueft der Backend-Test
/// (`RvgFeeCalculatorTests`), hier zaehlt nur, dass die Vorschau nicht haengt.
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

/// Der Cubit wird im Test nie geladen — das Formular startet dann mit der
/// Vorgabe aus dem Code, wie vor der Konfigurierbarkeit.
class _NieGeladeneStandardpositionen
    implements StandardSchadenspositionenRepository {
  @override
  Future<List<StandardSchadensposition>> lade() => throw UnimplementedError();

  @override
  Future<List<StandardSchadensposition>> speichere(
    List<StandardSchadensposition> positionen,
  ) => throw UnimplementedError();
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

/// Aufbau und Abbau des Schritts. Anlegen, in `tearDown` [schliesse] rufen —
/// auch dann, wenn [zeige] nie lief.
class SchadensaufstellungSchritt {
  WizardUmgebung? _umgebung;
  DocumentBloc? _document;

  /// Der Wizard hinter dem Schritt — fuer Zusicherungen ueber den gemeldeten
  /// Stand (`umgebung.wizard.state.damageListing`). Erst nach [zeige] da.
  WizardUmgebung get umgebung => _umgebung!;

  Future<void> zeige(WidgetTester tester) async {
    final umgebung = WizardUmgebung();
    umgebung.wizard.setFormData({'Name': 'Mustermann'});
    final dokument = DocumentBloc(_FakeVorlagenUebersicht());
    dokument.add(const SetDocumentPathEvent(r'C:\Vorlagen\HGN.docx'));
    _umgebung = umgebung;
    _document = dokument;

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: umgebung.wizard),
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
          BlocProvider(
            create: (_) =>
                StandardpositionenCubit(_NieGeladeneStandardpositionen()),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WizardStepSchadensaufstellung()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Die beiden Blocs gehen als `BlocProvider.value` in den Baum; deren Vertrag
  /// laesst die Lebensdauer beim Aufrufer — anders als bei
  /// `BlocProvider(create:)`, das seine Blocs selbst schliesst. Ohne dieses
  /// Schliessen blieben je Test acht StreamController offen, und sobald einer
  /// dieser Blocs einmal einen Timer startet, schlaegt er in einem *anderen*
  /// Test als „A Timer is still pending" auf.
  Future<void> schliesse() async {
    await _umgebung?.schliesse();
    await _document?.close();
    _umgebung = null;
    _document = null;
  }
}

/// Wartet die Entprellung des [RvgCalculationBloc] (350 ms) ab. `pumpAndSettle`
/// allein reicht dafuer **nicht**: Ein wartender Timer plant kein Bild ein, die
/// Schleife haelt ihn also fuer erledigt — und der Test faellt am Ende ueber
/// „A Timer is still pending".
Future<void> beruhige(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

CustomRectangularButton erstellenKnopf(WidgetTester tester) => tester
    .widgetList<CustomRectangularButton>(find.byType(CustomRectangularButton))
    .firstWhere(
      (knopf) =>
          knopf.label is Text &&
          (knopf.label as Text).data == 'Dokument erstellen',
    );
