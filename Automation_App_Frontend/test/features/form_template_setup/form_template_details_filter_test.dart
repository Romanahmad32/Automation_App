import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/pages/form_template_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Filterzähler der Felderkarte („Nur offene (N)") muss jeder Umbenennung
/// eines Feldnamens **ohne** weitere Aktion folgen (#104).
///
/// Der Aufbau ist der aus `vorlagen_verlassen_test.dart` (echte
/// `FormTemplateDetailsPage`, echte Blocs, von Hand geschriebene Fakes statt
/// einer Mock-Bibliothek — dieser Testordner kennt keine). Anders als dort
/// geht es hier nicht um den Weg hinaus, sondern um die Zahl auf dem
/// `SegmentedButton` aus `felder_karte_kopf.dart`: Sie hängt vom
/// `TemplatePlaceholdersBloc`-Zustand **und** vom Formular ab, und nur die
/// FormGroup ändert sich beim Tippen — kein `TemplatePlaceholdersBloc`-Ereignis,
/// kein `setState` der Seite. Ohne den `ReactiveFormConsumer` um
/// `TemplateFieldsCard` (siehe `form_template_details_page.dart`) hinkt die
/// Zahl deshalb jeder Umbenennung hinterher.
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
  // Zwei Felder, eine verknüpfte Datei mit den Platzhaltern „Mandant" und
  // „Frist": „Mandant" trifft auf das gleichnamige Feld, „Unbekannt" auf
  // keinen der beiden — und „Frist" bleibt umgekehrt ohne Feld. Erst das
  // Umbenennen von „Unbekannt" auf „Frist" schliesst beide Lücken zugleich.
  const vorlage = FormTemplate(
    id: 11,
    templateName: 'Anspruchsschreiben',
    fields: [
      FieldData(
        order: 0,
        label: 'Mandant',
        required: true,
        inputType: InputType.text,
      ),
      FieldData(
        order: 1,
        label: 'Unbekannt',
        required: false,
        inputType: InputType.text,
      ),
    ],
    wordFilePathOhneAuflistung: 'HGn.docx',
  );

  // Solange die Seite offen ist, steht in `FieldData.label` nur der
  // Control-Schlüssel (`field_0`, `field_1`, …) — der echte Name liegt im
  // Wert des Controls (siehe FEATURE.md/FALLSTRICKE.md des Features). Das
  // zweite Feld ist deshalb über `field_1` zu finden.
  final zweitesFeld = find.byWidgetPredicate(
    (widget) =>
        widget is GeneralTextField && widget.formControlName == 'field_1',
  );

  testWidgets(
    'die Filterzahl folgt der Umbenennung eines Feldes ohne weitere Aktion',
    (tester) async {
      // Die Feldzeilen sind für die 800-px-Standardfläche des Testers zu
      // schmal (wie in `vorlagen_verlassen_test.dart`).
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
            child: const FormTemplateDetailsPage(formTemplate: vorlage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zwei offene Punkte: der Platzhalter „Frist" hat noch kein Feld, und
      // das Feld „Unbekannt" trifft auf keinen Platzhalter — beide zählen in
      // `VorlagenStand.anzahlOffen` mit.
      expect(find.text('Nur offene (2)'), findsOneWidget);

      // Auf „Alle" umschalten, um an die Zeile von „Unbekannt" heranzukommen
      // — unter „Nur offene" bleibt sie aus, weil ein leerer/unpassender
      // Name allein keine Zeile zeigt, sondern nur die Zählung oben trägt.
      // Das Umschalten selbst ändert nichts an der Rechnung: `_gewaehlt` sitzt
      // im lokalen Zustand von `TemplateFieldsCard`, `stand` bekommt die Karte
      // weiterhin von aussen.
      await tester.tap(find.text('Alle'));
      await tester.pumpAndSettle();

      await tester.enterText(zweitesFeld, 'Frist');
      // Ein einzelnes `pump`, kein `pumpAndSettle`: Genau der eine Rebuild
      // nach der FormGroup-Änderung ist es, den der `ReactiveFormConsumer`
      // auslösen muss — nicht irgendein späterer, durch etwas anderes
      // angestossener.
      await tester.pump();

      // Jetzt trifft „Unbekannt" (jetzt „Frist") auf den gleichnamigen
      // Platzhalter — nichts bleibt offen.
      expect(find.text('Nur offene (0)'), findsOneWidget);
      expect(find.text('Nur offene (2)'), findsNothing);
    },
  );
}
