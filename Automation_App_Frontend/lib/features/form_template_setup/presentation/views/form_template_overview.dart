import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FormTemplateOverview extends StatelessWidget {
  final FormTemplateOverviewLoaded state;

  const FormTemplateOverview({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    // Keine einzige Vorlage angelegt -> reiner Leerzustand ohne Suchleiste.
    if (state.formTemplates.isEmpty) {
      return _buildEmptyState(context);
    }

    final filtered = state.filteredTemplates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntitySearchBar(
          initialQuery: state.query,
          hintText: 'Vorlagen nach Name oder Feld durchsuchen …',
          onChanged: (value) => context.read<FormTemplateOverviewBloc>().add(
            SearchFormTemplatesEvent(query: value),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? _buildNoResultsState(context)
              : FormTemplateTable(templates: filtered),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            _resultLabel(filtered.length),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }

  String _resultLabel(int count) {
    final noun = count == 1 ? 'Vorlage' : 'Vorlagen';
    if (state.query.trim().isEmpty) return '$count $noun';
    return '$count von ${state.formTemplates.length} $noun';
  }

  Widget _buildNoResultsState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Keine Vorlage passt zu „${state.query}".',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Noch keine Vorlagen gespeichert',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Legen Sie über "Neue Vorlage erstellen" Ihre erste Vorlage an.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
