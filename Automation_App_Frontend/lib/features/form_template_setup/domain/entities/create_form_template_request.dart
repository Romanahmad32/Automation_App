import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';

class CreateFormTemplateRequest {
  final String templateName;
  final List<FieldData> fields;
  final String? wordFilePathOhneAuflistung;
  final String? wordFilePathMitAuflistung;

  const CreateFormTemplateRequest({
    required this.templateName,
    required this.fields,
    this.wordFilePathOhneAuflistung,
    this.wordFilePathMitAuflistung,
  });

  Map<String, dynamic> toJson() => {
    'templateName': templateName,
    'fields': fields.map((e) => e.toJson()).toList(),
    'wordFilePathOhneAuflistung': wordFilePathOhneAuflistung,
    'wordFilePathMitAuflistung': wordFilePathMitAuflistung,
  };
}
