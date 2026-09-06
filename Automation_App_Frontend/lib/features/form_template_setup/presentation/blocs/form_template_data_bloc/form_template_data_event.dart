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

  /// Der Stand, den der Editor beim Drücken des Knopfs gerechnet hat (#104
  /// Stufe 4) — er reist in der opaken `fields`-Spalte mit, damit die
  /// Übersicht ihn zeigen kann, ohne die Word-Dateien zu lesen. Null lässt die
  /// Spalte in ihrer alten Form (siehe `GespeicherterStand`).
  final GespeicherterStand? stand;

  const SubmitFormTemplateDataEvent({
    this.templateName,
    this.existingItemId,
    required this.formData,
    this.wordFilePathOhneAuflistung,
    this.wordFilePathMitAuflistung,
    this.stand,
  });

  @override
  List<Object?> get props => [
    existingItemId,
    templateName,
    formData,
    wordFilePathOhneAuflistung,
    wordFilePathMitAuflistung,
    stand,
  ];
}
