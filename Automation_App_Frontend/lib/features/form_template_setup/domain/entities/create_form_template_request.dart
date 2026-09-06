import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';

class CreateFormTemplateRequest {
  final String templateName;
  final List<FieldData> fields;
  final String? wordFilePathOhneAuflistung;
  final String? wordFilePathMitAuflistung;

  /// Der Stand, den die Übersicht später anzeigt (#104 Stufe 4) — `null` heißt
  /// „unbekannt" und lässt die `fields`-Spalte in ihrer alten, nackten Form.
  /// Siehe [GespeicherterStand].
  final GespeicherterStand? stand;

  const CreateFormTemplateRequest({
    required this.templateName,
    required this.fields,
    this.wordFilePathOhneAuflistung,
    this.wordFilePathMitAuflistung,
    this.stand,
  });

  Map<String, dynamic> toJson() => {
    'templateName': templateName,
    'fields': GespeicherterStand.verpacke([
      for (final feld in fields) feld.toJson(),
    ], stand),
    'wordFilePathOhneAuflistung': wordFilePathOhneAuflistung,
    'wordFilePathMitAuflistung': wordFilePathMitAuflistung,
  };
}
