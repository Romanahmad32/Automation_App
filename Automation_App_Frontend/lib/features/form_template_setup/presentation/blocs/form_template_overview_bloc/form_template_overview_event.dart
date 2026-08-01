part of 'form_template_overview_bloc.dart';

sealed class FormTemplateOverviewEvent extends Equatable {
  const FormTemplateOverviewEvent();
}

final class LoadFormTemplatesEvent extends FormTemplateOverviewEvent {
  @override
  List<Object> get props => [];
}

/// Aktualisiert den Suchfilter der Overview. Leerer String zeigt wieder alle
/// Vorlagen. Filtert ueber Vorlagenname und Feld-Labels (case-insensitive).
final class SearchFormTemplatesEvent extends FormTemplateOverviewEvent {
  final String query;

  const SearchFormTemplatesEvent({required this.query});

  @override
  List<Object> get props => [query];
}

final class DeleteFormTemplateEvent extends FormTemplateOverviewEvent {
  final int templateId;

  const DeleteFormTemplateEvent({required this.templateId});

  @override
  List<Object> get props => [templateId];
}
