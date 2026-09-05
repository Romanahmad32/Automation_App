import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Baut den Ausgangszustand des Vorlagen-Detailformulars: die [FormGroup] mit
/// dem Namensfeld und – im Bearbeiten-Modus – einem Control je vorhandenem Feld,
/// die zugehörige [FieldData]-Liste und den nächsten freien Feldindex.
class InitialTemplateForm {
  final FormGroup formGroup;
  final List<FieldData> fields;
  final int nextFieldIndex;

  const InitialTemplateForm({
    required this.formGroup,
    required this.fields,
    required this.nextFieldIndex,
  });

  factory InitialTemplateForm.fromTemplate(FormTemplate? template) {
    final controls = <String, AbstractControl<dynamic>>{
      'templateName': FormControl<String>(
        value: template?.templateName,
        validators: [Validators.required],
      ),
    };

    final fields = <FieldData>[];
    int index = 0;
    for (final element in template?.fields ?? const <FieldData>[]) {
      final fieldKey = 'field_$index';
      // Das gespeicherte Feld fortschreiben, nicht neu bauen: `copyWith`
      // bringt die Datums-Vorbelegung mit (§5.3, #105). Ein Neubau liesse sie
      // fallen, und der Editor einer Bestandsvorlage stünde immer auf „nicht
      // eingestellt", obwohl etwas gespeichert ist. Getauscht wird nur das
      // Label: Solange die Seite offen ist, steht dort der Control-Schlüssel.
      fields.add(element.copyWith(order: index, label: fieldKey));
      controls[fieldKey] = FormControl<String>(
        value: element.label,
        validators: element.required ? [Validators.required] : [],
      );
      index++;
    }

    return InitialTemplateForm(
      formGroup: FormGroup(controls),
      fields: fields,
      nextFieldIndex: index,
    );
  }
}
