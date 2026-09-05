import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_action_buttons.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/initial_template_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der **Weg** der Datums-Vorbelegung (§5.3) durch den Vorlageneditor — hinein
/// beim Speichern, heraus beim Öffnen.
///
/// Die Lücke, die #105 aufdeckte, lag genau zwischen den vorhandenen Tests:
/// Der Einsteller (`datums_vorbelegung_editor_test.dart`), die Rechnung
/// (`datums_vorbelegung_test.dart`) und die Entität samt JSON
/// (`field_data_vorbelegung_test.dart`) waren je für sich grün, während beide
/// Enden die Angabe still fallen liessen. Weil `toJson` den Schlüssel bei
/// `null` gar nicht schreibt, war der Verlust von aussen nicht von „nie
/// eingestellt" zu unterscheiden — kein Fehler, keine Meldung, nur das falsche
/// Datum im nächsten Schreiben.
///
/// Geprüft wird deshalb nicht der Einsteller, sondern was **unten ankommt**:
/// die Vorlage, die der UseCase zu sehen bekommt.

/// Merkt sich die Anfrage, statt sie zu verschicken. Ein von Hand geschriebener
/// Fake wie `FestePlatzhalter` in `template_fields_card_reorder_test.dart` —
/// dieser Testordner kennt keine Mock-Bibliothek.
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
  /// Ein Datumsfeld so, wie es auf der offenen Detailseite steht: In [label]
  /// liegt der Control-Schlüssel, nicht der Feldname (siehe `FALLSTRICKE.md`).
  FieldData datumsfeld(int index, {DatumsVorbelegung? vorbelegung}) =>
      FieldData(
        order: index,
        label: 'field_$index',
        required: true,
        inputType: InputType.date,
        datenquelle: FeldDatenquelle.keine,
        vorbelegung: vorbelegung,
      );

  /// Der Formularaufbau der Detailseite in klein: der Vorlagenname und je Feld
  /// ein Control unter dem Schlüssel, der in `FieldData.label` steht. Der
  /// Speichern-Knopf ist nur bei gültigem Formular überhaupt drückbar.
  FormGroup formularMit(Map<String, String> feldnamen) => FormGroup({
    'templateName': FormControl<String>(
      value: 'Anspruchsschreiben',
      validators: [Validators.required],
    ),
    for (final eintrag in feldnamen.entries)
      eintrag.key: FormControl<String>(
        value: eintrag.value,
        validators: [Validators.required],
      ),
  });

  /// Drückt „Vorlage speichern" und gibt die Felder zurück, die dabei unten
  /// ankommen — über `FormTemplateActionButtons`, `FormTemplateDataBloc` und
  /// den UseCase, also den vollen Speicherweg.
  Future<List<FieldData>> speichere(
    WidgetTester tester, {
    required List<FieldData> fields,
    required FormGroup formGroup,
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
              formGroup: formGroup,
              child: FormTemplateActionButtons(
                onCancel: () {},
                fields: fields,
                // Bestandsvorlage: genau der Fall aus #105 — öffnen, etwas
                // ändern, speichern.
                existingItemId: 7,
                wordFilePathOhneAuflistung: 'HGN.docx',
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

    return aktualisieren.letzteAnfrage!.formTemplate.fields;
  }

  testWidgets('der Speichern-Knopf reicht die eingestellte Vorbelegung durch', (
    tester,
  ) async {
    final gespeichert = await speichere(
      tester,
      fields: [
        datumsfeld(0, vorbelegung: const DatumsVorbelegung(jahre: 1, tage: 4)),
      ],
      formGroup: formularMit({'field_0': 'Zahlungsfrist'}),
    );

    // Der Feldname kommt aus dem Control, die Vorbelegung aus dem Feld.
    expect(gespeichert.single.label, 'Zahlungsfrist');
    expect(
      gespeichert.single.vorbelegung,
      const DatumsVorbelegung(jahre: 1, tage: 4),
    );
  });

  testWidgets('„bewusst heute" überlebt das Speichern als eigener Stand', (
    tester,
  ) async {
    // Lauter Nullen sind nicht dasselbe wie null: Fielen sie beim Speichern
    // auf null zurück, schaltete sich an einem Feld namens „Zahlungsfrist" die
    // Namensregel wieder ein, die der Anwalt gerade abgeschaltet hat.
    final gespeichert = await speichere(
      tester,
      fields: [datumsfeld(0, vorbelegung: const DatumsVorbelegung())],
      formGroup: formularMit({'field_0': 'Zahlungsfrist'}),
    );

    expect(gespeichert.single.vorbelegung, isNotNull);
    expect(gespeichert.single.vorbelegung!.istHeute, isTrue);
    expect(gespeichert.single.toJson().containsKey('vorbelegung'), isTrue);
  });

  testWidgets('ohne Einstellung bleibt der Schlüssel weiterhin aus dem JSON', (
    tester,
  ) async {
    // Die Gegenprobe zu den beiden oben: Ein blosses Öffnen und Speichern darf
    // an einem Bestandsfeld nichts einschalten — sonst verlöre jede alte
    // Vorlage ihre Namensregel, ohne dass jemand etwas angefasst hätte.
    final gespeichert = await speichere(
      tester,
      fields: [
        datumsfeld(0),
        datumsfeld(1, vorbelegung: const DatumsVorbelegung(wochen: 3)),
      ],
      formGroup: formularMit({
        'field_0': 'Unfalldatum',
        'field_1': 'Zahlungsfrist',
      }),
    );

    expect(gespeichert.first.vorbelegung, isNull);
    expect(gespeichert.first.toJson().containsKey('vorbelegung'), isFalse);
    expect(gespeichert.last.vorbelegung, const DatumsVorbelegung(wochen: 3));
    // Die Reihenfolge kommt aus dem Laufindex, nicht mehr aus einer Suche.
    expect(gespeichert.map((feld) => feld.order), [0, 1]);
  });

  test('eine geöffnete Vorlage bringt ihre gespeicherte Vorbelegung mit', () {
    final initial = InitialTemplateForm.fromTemplate(
      const FormTemplate(
        id: 7,
        templateName: 'Anspruchsschreiben',
        fields: [
          FieldData(
            order: 0,
            label: 'Zahlungsfrist',
            required: true,
            inputType: InputType.date,
            vorbelegung: DatumsVorbelegung(wochen: 2),
          ),
          FieldData(
            order: 1,
            label: 'Unfalldatum',
            required: true,
            inputType: InputType.date,
          ),
        ],
      ),
    );

    // Stünde hier null, zeigte der Editor die Namensregel — für
    // „Zahlungsfrist" also 5 Wochen statt der gespeicherten 2.
    expect(
      initial.fields.first.vorbelegung,
      const DatumsVorbelegung(wochen: 2),
    );
    // Und das zweite Feld bleibt, was es ist: nie angefasst.
    expect(initial.fields.last.vorbelegung, isNull);
    // Getauscht wird nur das Label; der Name zieht in das Control um.
    expect(initial.fields.first.label, 'field_0');
    expect(initial.formGroup.control('field_0').value, 'Zahlungsfrist');
  });

  testWidgets('öffnen und speichern lässt die Vorbelegung unverändert', (
    tester,
  ) async {
    // Der ganze Weg am Stück — beide Enden aus #105 in einem Test. Wäre eines
    // von beiden wieder kaputt, käme hier null heraus.
    final initial = InitialTemplateForm.fromTemplate(
      const FormTemplate(
        id: 7,
        templateName: 'Anspruchsschreiben',
        fields: [
          FieldData(
            order: 0,
            label: 'Zahlungsfrist',
            required: true,
            inputType: InputType.date,
            vorbelegung: DatumsVorbelegung(monate: 1, tage: 10),
          ),
        ],
      ),
    );

    final gespeichert = await speichere(
      tester,
      fields: initial.fields,
      formGroup: initial.formGroup,
    );

    expect(gespeichert.single.label, 'Zahlungsfrist');
    expect(
      gespeichert.single.vorbelegung,
      const DatumsVorbelegung(monate: 1, tage: 10),
    );
  });
}
