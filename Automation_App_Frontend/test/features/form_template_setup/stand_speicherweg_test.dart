import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_action_buttons.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_bearbeitung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der **Weg** des Stands (#104 Stufe 4) durch den Speichern-Knopf.
///
/// `_standJetzt()` (`form_template_details_page.dart`) rechnet ihn beim Klick
/// aus dem `TemplatePlaceholdersBloc`-Zustand und `VorlagenBearbeitung.stand`
/// und reicht ihn über `standErmitteln:` an `FormTemplateActionButtons`
/// weiter. Kein vorhandener Test deckte diesen Weg — nur die Rechnung selbst
/// (`vorlagen_stand_test.dart`, `gespeicherter_stand_test.dart`) und der
/// Speicherweg ohne Stand (`datums_vorbelegung_speicherweg_test.dart`).
///
/// Geprüft wird deshalb, was **unten ankommt**: die Vorlage, die der UseCase
/// zu sehen bekommt — mit einem `stand`, der aus einer echten Rechnung stammt,
/// nicht aus einem Stub.

/// Merkt sich die Anfrage, statt sie zu verschicken. Ein von Hand geschriebener
/// Fake wie in `datums_vorbelegung_speicherweg_test.dart` — dieser Testordner
/// kennt keine Mock-Bibliothek.
class MerkendesErstellen implements UseCase<void, CreateFormTemplateRequest> {
  CreateFormTemplateRequest? letzteAnfrage;

  @override
  Future<Either<Failure, void>> call(CreateFormTemplateRequest params) async {
    letzteAnfrage = params;
    return Right(null);
  }
}

class MerkendesAktualisieren
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  UpdateFormTemplateParams? letzteAnfrage;

  @override
  Future<Either<Failure, FormTemplate>> call(
    UpdateFormTemplateParams params,
  ) async {
    letzteAnfrage = params;
    return Right(params.formTemplate);
  }
}

void main() {
  /// Eine befüllte Bearbeitung wie beim Öffnen einer Bestandsvorlage: ein Feld
  /// und eine Word-Datei ohne Auflistung.
  VorlagenBearbeitung bearbeitungMit(String feldname) => VorlagenBearbeitung(
    formGroup: FormGroup({
      'templateName': FormControl<String>(
        value: 'Anspruchsschreiben',
        validators: [Validators.required],
      ),
      'field_0': FormControl<String>(
        value: feldname,
        validators: [Validators.required],
      ),
    }),
    fields: [
      const FieldData(
        order: 0,
        label: 'field_0',
        required: true,
        inputType: InputType.text,
      ),
    ],
    nextFieldIndex: 1,
    pfadOhneAuflistung: 'HGN.docx',
    pfadMitAuflistung: null,
  );

  /// Der Zustand, wie ihn der `TemplatePlaceholdersBloc` nach einer gelesenen
  /// Datei zeigt: zwei Platzhalter, von denen nur einer ein Feld hat.
  const zustandMitOffenemPlatzhalter = TemplatePlaceholdersState(
    slots: {
      TemplateFileSlot.ohneAuflistung: SlotPlaceholdersLoaded([
        'Zahlungsfrist',
        'Unfalldatum',
      ]),
    },
  );

  /// Drückt „Vorlage speichern" und gibt die Vorlage zurück, die dabei unten
  /// ankommt — über `FormTemplateActionButtons`, `FormTemplateDataBloc` und den
  /// UseCase, also den vollen Speicherweg.
  Future<FormTemplate> speichere(
    WidgetTester tester, {
    required VorlagenBearbeitung bearbeitung,
    required GespeicherterStand Function()? standErmitteln,
  }) async {
    final aktualisieren = MerkendesAktualisieren();
    final bloc = FormTemplateDataBloc(MerkendesErstellen(), aktualisieren);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: ReactiveForm(
              formGroup: bearbeitung.formGroup,
              child: FormTemplateActionButtons(
                onCancel: () {},
                fields: bearbeitung.fields,
                // Bestandsvorlage: derselbe Fall wie beim Datums-Speicherweg —
                // öffnen, etwas ändern, speichern.
                existingItemId: 7,
                wordFilePathOhneAuflistung: bearbeitung.pfadOhneAuflistung,
                standErmitteln: standErmitteln,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Vorlage speichern'));
    await tester.pump();
    // Der Bloc wartet nach dem Schreiben 200 ms, bevor er „fertig" meldet;
    // ohne das Abwarten bliebe ein Timer offen und der Test schlüge an.
    await tester.pump(const Duration(milliseconds: 300));

    return aktualisieren.letzteAnfrage!.formTemplate;
  }

  testWidgets('der Speichern-Knopf reicht den echt gerechneten Stand durch', (
    tester,
  ) async {
    final bearbeitung = bearbeitungMit('Zahlungsfrist');

    final gespeichert = await speichere(
      tester,
      bearbeitung: bearbeitung,
      // Dieselbe Rechnung wie `_standJetzt()` in
      // `form_template_details_page.dart`: kein Stub, sondern die echte Kette
      // aus `VorlagenBearbeitung.stand` und `GespeicherterStand.aus`. Das Feld
      // `Unfalldatum` steht in der Datei, hat aber kein Feld — genau ein
      // offener Platzhalter, also unvollständig.
      standErmitteln: () => GespeicherterStand.aus(
        bearbeitung.stand(zustandMitOffenemPlatzhalter),
      ),
    );

    expect(gespeichert.stand, isNotNull);
    expect(gespeichert.stand!.vollstaendig, isFalse);
    expect(gespeichert.stand!.offen, 1);
  });
}
