import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/usecases/fill_out_template.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/wizard_step_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wizard_doubles.dart';

/// Der Wizard erzeugt in diesem Test nie ein Dokument — es geht nur um die
/// Schrittleiste, die den Bloc lediglich beobachtet.
class _NieAusgefuellteVorlage
    implements UseCase<GeneratedDocument, FillOutTemplateParams> {
  @override
  Future<Either<Failure, GeneratedDocument>> call(
    FillOutTemplateParams params,
  ) => throw UnimplementedError();
}

/// Bei rund 1300 px Fensterbreite (Sidebar ausgeklappt) lief die Schrittleiste
/// mit der angehobenen Schrift (Issue #57) rechts über — der dritte
/// Schritt-Chip war abgeschnitten. Der Test pumpt sie mit allen vier
/// Schritten (die breiteste Ausprägung, „mit Auflistung") bei schmaler
/// Fensterbreite und erwartet keine RenderFlex-Überlauf-Exception.
void main() {
  final offen = <WizardUmgebung>[];

  tearDown(() async {
    for (final umgebung in offen) {
      await umgebung.schliesse();
    }
    offen.clear();
  });

  Future<void> zeigeLeiste(
    WidgetTester tester, {
    required double breite,
  }) async {
    final umgebung = WizardUmgebung();
    offen.add(umgebung);
    // Alle vier Schritte sichtbar (auch „Schadensaufstellung") — die
    // breiteste Ausprägung der Leiste.
    umgebung.wizard.setMitAuflistung(true);

    tester.view.physicalSize = Size(breite, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: umgebung.wizard),
          BlocProvider(
            create: (_) => EditedDocumentBloc(_NieAusgefuellteVorlage()),
          ),
        ],
        child: MaterialApp(
          // Das echte, angehobene Theme (Issue #57) statt eines leeren
          // TextTheme — sonst bliebe der Test blind für Größenänderungen.
          theme: MaterialTheme(ThemeData.light().textTheme).light(),
          home: const Scaffold(body: WizardStepBar()),
        ),
      ),
    );
  }

  testWidgets('überläuft nicht bei schmalem Fenster und angehobener Schrift', (
    tester,
  ) async {
    await zeigeLeiste(tester, breite: 500);

    expect(tester.takeException(), isNull);
  });

  testWidgets('überläuft nicht bei ausgeklappter Sidebar (~1300 px Fenster)', (
    tester,
  ) async {
    // Vom Fenster bleibt abzüglich Sidebar und Seitenrand deutlich weniger
    // als 1300 px für die Leiste selbst — das reproduziert den Befund.
    await zeigeLeiste(tester, breite: 900);

    expect(tester.takeException(), isNull);
  });
}
