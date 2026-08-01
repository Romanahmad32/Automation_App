part of 'form_template_overview_bloc.dart';

sealed class FormTemplateOverviewState extends Equatable {
  const FormTemplateOverviewState();
}

final class FormTemplateOverviewLoading extends FormTemplateOverviewState {
  @override
  List<Object> get props => [];
}

final class FormTemplateOverviewLoaded extends FormTemplateOverviewState {
  /// Die vollstaendige, ungefilterte Vorlagenliste (Quelle der Wahrheit).
  final List<FormTemplate> formTemplates;

  /// Aktueller Suchbegriff. Leer = kein Filter.
  final String query;

  const FormTemplateOverviewLoaded(this.formTemplates, {this.query = ''});

  /// Die nach [query] gefilterte Liste fuer die Anzeige. Trifft auf den
  /// Vorlagennamen oder ein beliebiges Feld-Label (case-insensitive).
  List<FormTemplate> get filteredTemplates {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return formTemplates;
    return formTemplates.where((template) {
      if (template.templateName.toLowerCase().contains(q)) return true;
      return template.fields.any(
        (field) => field.label.toLowerCase().contains(q),
      );
    }).toList();
  }

  @override
  List<Object> get props => [formTemplates, query];
}

final class FormTemplateOverviewError extends FormTemplateOverviewState {
  final String message;

  const FormTemplateOverviewError(this.message);

  @override
  List<Object?> get props => [message];
}
