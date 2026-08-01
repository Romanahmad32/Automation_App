part of 'form_template_data_bloc.dart';

sealed class FormTemplateDataEvent extends Equatable {
  const FormTemplateDataEvent();
}

final class SubmitFormTemplateDataEvent extends FormTemplateDataEvent {
  final int? existingItemId;
  final String? templateName;
  final List<FieldData> formData;
  final String? wordFilePathOhneAuflistung;
  final String? wordFilePathMitAuflistung;

  const SubmitFormTemplateDataEvent({
    this.templateName,
    this.existingItemId,
    required this.formData,
    this.wordFilePathOhneAuflistung,
    this.wordFilePathMitAuflistung,
  });

  @override
  List<Object?> get props =>
      [
        existingItemId,
        templateName,
        formData,
        wordFilePathOhneAuflistung,
        wordFilePathMitAuflistung,
      ];
}
