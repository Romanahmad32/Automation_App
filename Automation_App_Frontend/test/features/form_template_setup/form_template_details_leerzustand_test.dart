import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/pages/form_template_details_page.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_name_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_dateiwahl.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_leerzustand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Ablauf „Datei zuerst" an der echten Detailseite (#104 Stufe 3c):
/// Eine neue Vorlage beginnt mit **einer** Frage, und alles Weitere — Name,
/// Felder — leitet die App aus der gewählten Datei ab.
///
/// Aufbau wie in `vorlagen_verlassen_test.dart` und
/// `form_template_details_filter_test.dart`: echte Seite, echte Blocs, von
/// Hand geschriebene Fakes (dieser Testordner kennt keine Mock-Bibliothek).
/// Neu ist nur die Dateiwahl: Sie führt sonst in einen Plattformkanal, den ein
/// Widget-Test nicht bedienen kann, und wird über [VorlagenDateiwahl.waehle]
/// ersetzt (siehe die Begründung dort — die Seite kann sie nicht als Parameter
/// nehmen, ihr Konstruktor speist die generierte auto_route-Route).
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(const ['Mandant', 'Frist']);
}

class StillesErstellen implements UseCase<void, CreateFormTemplateRequest> {
  @override
  Future<Either<Failure, void>> call(CreateFormTemplateRequest params) async =>
      Right(null);
}

class StillesAktualisieren
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  @override
  Future<Either<Failure, FormTemplate>> call(
    UpdateFormTemplateParams params,
  ) async => Right(params.formTemplate);
}

void main() {
  // Der Dateiname trägt Präfix und Suffix der Kanzleiablage; übrig bleiben
  // muss „Anspruchsschreiben" (siehe `vorlagenname_vorschlag_test.dart`).
  const gewaehlt =
      'C:/Vorlagen/VORLAGE Anspruchsschreiben ohne Auflistung.docx';

  final namensfeld = find.byWidgetPredicate(
    (widget) =>
        widget is GeneralTextField && widget.formControlName == 'templateName',
  );

  /// Beide Wahlflächen tragen denselben Knopf — auseinanderzuhalten sind sie
  /// nur über den Schlüssel ihrer Fläche (wie in `vorlagen_leerzustand_test`).
  final dateiWaehlen = find.descendant(
    of: find.byKey(const ValueKey(TemplateFileSlot.ohneAuflistung)),
    matching: find.widgetWithText(CustomRectangularButton, 'Datei wählen…'),
  );

  Future<void> oeffneNeueVorlage(WidgetTester tester) async {
    // Die Feldzeilen sind für die 800-px-Standardfläche des Testers zu schmal.
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    VorlagenDateiwahl.waehle = (context) async => gewaehlt;
    addTearDown(VorlagenDateiwahl.zuruecksetzen);

    final platzhalter = TemplatePlaceholdersBloc(FestePlatzhalter());
    addTearDown(platzhalter.close);
    final daten = FormTemplateDataBloc(
      StillesErstellen(),
      StillesAktualisieren(),
    );
    addTearDown(daten.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: daten),
            BlocProvider.value(value: platzhalter),
          ],
          // Kein `formTemplate`: Das ist der Anlegen-Modus.
          child: const FormTemplateDetailsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('eine neue Vorlage ohne Datei zeigt nur die eine Frage', (
    tester,
  ) async {
    await oeffneNeueVorlage(tester);

    expect(find.text('Neue Vorlage erstellen'), findsOneWidget);
    expect(find.byType(VorlagenLeerzustand), findsOneWidget);

    // Weder Name noch Felder: Beides leitet sich aus der Datei ab, und ein
    // leeres Formular daneben sähe aus, als sei etwas kaputt.
    expect(find.byType(TemplateNameCard), findsNothing);
    expect(find.byType(TemplateFieldsCard), findsNothing);

    // Speichern ist weg, Abbrechen bleibt — sonst gäbe es keinen Weg zurück.
    expect(find.text('Vorlage erstellen'), findsNothing);
    expect(find.text('Abbrechen'), findsOneWidget);
  });

  testWidgets('mit der Datei kommen Layout, Felder und der Namensvorschlag', (
    tester,
  ) async {
    await oeffneNeueVorlage(tester);

    await tester.tap(dateiWaehlen);
    await tester.pumpAndSettle();

    expect(find.byType(VorlagenLeerzustand), findsNothing);
    expect(find.byType(TemplateNameCard), findsOneWidget);
    expect(find.byType(TemplateFieldsCard), findsOneWidget);
    expect(find.text('Vorlage erstellen'), findsOneWidget);

    // Der Name steht im Feld, und darunter steht, woher er kommt.
    expect(find.text('Anspruchsschreiben'), findsOneWidget);
    expect(
      find.text(
        'Vorschlag aus VORLAGE Anspruchsschreiben ohne Auflistung.docx'
        ' — bei Bedarf anpassen',
      ),
      findsOneWidget,
    );

    // Die erkannten Platzhalter sind zu Feldern geworden (Ablauf „Datei
    // zuerst") und gemeldet worden.
    expect(find.text('Mandant'), findsWidgets);
    expect(find.text('Frist'), findsWidgets);
    expect(
      find.textContaining('2 Platzhalter erkannt, 2 Felder angelegt'),
      findsOneWidget,
    );
  });

  testWidgets('der Hinweis verschwindet, sobald der Name geändert wird', (
    tester,
  ) async {
    await oeffneNeueVorlage(tester);

    await tester.tap(dateiWaehlen);
    await tester.pumpAndSettle();

    await tester.enterText(namensfeld, 'Mahnschreiben');
    // Ein einzelnes `pump`: Tippen ändert nur die FormGroup — genau der eine
    // Neuaufbau des `ReactiveFormConsumer` muss den Hinweis wegnehmen.
    await tester.pump();

    expect(find.textContaining('Vorschlag aus'), findsNothing);
    expect(find.text('Mahnschreiben'), findsOneWidget);
  });
}
