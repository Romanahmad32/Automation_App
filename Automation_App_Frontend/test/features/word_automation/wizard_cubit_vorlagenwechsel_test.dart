import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUpdateFormTemplate
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  @override
  Future<Either<Failure, FormTemplate>> call(UpdateFormTemplateParams params) =>
      throw UnimplementedError();
}

class _FakeGetMandanten implements UseCase<List<Mandant>, NoParams> {
  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async =>
      Right(const []);
}

/// Der gemeldete Fall (#37): Mitten im Ausfüllen fällt auf, dass ein Feld der
/// Vorlage noch umbenannt oder auf „nicht erforderlich" gestellt werden muss.
/// Die Vorlage wird nebenan bearbeitet, die Vorlagenliste lädt neu — und der
/// `TemplateSelector` meldet die geänderte Vorlage als *Auswahl*, weil er sie
/// per Wert mit der frischen Liste abgleicht. Das ist kein Vorlagenwechsel und
/// darf den Eingabestand nicht kosten.
void main() {
  FieldData feld(String label, {bool required = true}) => FieldData(
    order: 0,
    label: label,
    required: required,
    inputType: InputType.text,
  );

  FormTemplate vorlage({
    int id = 1,
    List<FieldData>? fields,
    String? ohne = r'C:\Vorlagen\ohne.docx',
    String? mit = r'C:\Vorlagen\mit.docx',
  }) => FormTemplate(
    id: id,
    templateName: 'Anspruchsschreiben',
    fields: fields ?? [feld('Versicherer')],
    wordFilePathOhneAuflistung: ohne,
    wordFilePathMitAuflistung: mit,
  );

  WizardCubit cubit() =>
      WizardCubit(_FakeUpdateFormTemplate(), _FakeGetMandanten());

  const aufstellung = DamageListing(
    items: [DamageItem(description: 'Reparaturkosten', amount: 500)],
  );

  test('dieselbe Vorlage in neuem Stand behält den Eingabestand', () async {
    final wizard = cubit();
    wizard.selectFormTemplate(vorlage());
    wizard.setMitAuflistung(true);
    wizard.setFormData(const {'Versicherer': 'HUK-COBURG'});
    wizard.setDamageListing(aufstellung);
    wizard.setVorsteuerabzugsberechtigt(false);
    wizard.goToStep(WizardStep.schadensaufstellung);

    // Feld umbenannt und auf „nicht erforderlich" gestellt — gleiche ID.
    final bearbeitet = vorlage(
      fields: [feld('Versicherung des Gegners', required: false)],
    );
    wizard.selectFormTemplate(bearbeitet);

    expect(wizard.state.selectedFormTemplate, bearbeitet);
    expect(wizard.state.formData, {'Versicherer': 'HUK-COBURG'});
    expect(wizard.state.formDataEntwurf, {'Versicherer': 'HUK-COBURG'});
    expect(wizard.state.damageListing, aufstellung);
    expect(wizard.state.mitAuflistung, isTrue);
    expect(wizard.state.vorsteuerabzugsberechtigt, isFalse);
    expect(wizard.state.currentStep, WizardStep.schadensaufstellung);
    await wizard.close();
  });

  test('eine andere Vorlage verwirft den Eingabestand', () async {
    final wizard = cubit();
    wizard.selectFormTemplate(vorlage());
    wizard.setMitAuflistung(true);
    wizard.setFormData(const {'Versicherer': 'HUK-COBURG'});
    wizard.setDamageListing(aufstellung, fehler: const ['Zeile 2 ohne Betrag']);
    wizard.setVorsteuerabzugsberechtigt(false);
    wizard.goToStep(WizardStep.schadensaufstellung);

    wizard.selectFormTemplate(vorlage(id: 2));

    expect(wizard.state.formData, isNull);
    expect(wizard.state.formDataEntwurf, isNull);
    expect(wizard.state.damageListing, isNull);
    expect(wizard.state.schadenspositionFehler, isEmpty);
    expect(wizard.state.mitAuflistung, isFalse);
    expect(wizard.state.vorsteuerabzugsberechtigt, isTrue);
    expect(wizard.state.currentStep, WizardStep.fillOut);
    await wizard.close();
  });

  /// Der Selector meldet `null`, wenn die gewählte Vorlage in der frischen
  /// Liste fehlt — sie wurde also gelöscht. Dann gibt es nichts mehr zu halten.
  test('gelöschte Vorlage verwirft den Eingabestand', () async {
    final wizard = cubit();
    wizard.selectFormTemplate(vorlage());
    wizard.setFormData(const {'Versicherer': 'HUK-COBURG'});

    wizard.selectFormTemplate(null);

    expect(wizard.state.selectedFormTemplate, isNull);
    expect(wizard.state.formData, isNull);
    expect(wizard.state.formDataEntwurf, isNull);
    await wizard.close();
  });

  test('Tippstand ist keine Freigabe des nächsten Schritts', () async {
    final wizard = cubit();
    wizard.selectFormTemplate(vorlage());
    wizard.setFormDataEntwurf(const {'Versicherer': 'HUK'});

    // `WizardStepBar._isEnabled` und der Erzeugen-Knopf der Schadens-
    // aufstellung hängen an formData — der bloße Tippstand schaltet nicht frei.
    expect(wizard.state.formData, isNull);
    expect(wizard.state.formDataEntwurf, {'Versicherer': 'HUK'});
    await wizard.close();
  });

  /// Verliert die aktualisierte Vorlage die gerade benutzte Fassung, fällt der
  /// Wizard auf die verbliebene zurück — und nimmt den Schritt mit, den es
  /// dann nicht mehr gibt.
  test('weggefallene Fassung schwenkt um und zieht den Schritt nach', () async {
    final wizard = cubit();
    wizard.selectFormTemplate(vorlage());
    wizard.setMitAuflistung(true);
    wizard.setFormData(const {'Versicherer': 'HUK-COBURG'});
    wizard.goToStep(WizardStep.schadensaufstellung);

    wizard.selectFormTemplate(vorlage(mit: null));

    expect(wizard.state.mitAuflistung, isFalse);
    expect(wizard.state.currentStep, WizardStep.fillOut);
    expect(wizard.state.formData, {'Versicherer': 'HUK-COBURG'});
    await wizard.close();
  });

  test('nur eine Fassung mit Auflistung wird weiterhin vorgewählt', () async {
    final wizard = cubit();

    wizard.selectFormTemplate(vorlage(ohne: null));

    expect(wizard.state.mitAuflistung, isTrue);
    expect(wizard.state.steps, contains(WizardStep.schadensaufstellung));
    await wizard.close();
  });
}
