import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/auflistung_badge.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_table_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eine Zeile der Vorlagen-Tabelle: Name, hinterlegte Word-Dateien (als
/// [AuflistungBadge]), Feldzahl und die Aktionen (bearbeiten/löschen).
class FormTemplateRow extends StatelessWidget {
  final FormTemplate template;

  const FormTemplateRow({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldCount = template.fields.length;
    final requiredCount = template.fields.where((f) => f.required).length;

    return InkWell(
      onTap: () => _navigateToDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            // Vorlage
            Expanded(
              flex: flexName,
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.templateName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Dateien
            Expanded(
              flex: flexFiles,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (template.hasOhneAuflistung)
                    AuflistungBadge(
                      label: 'ohne Auflistung',
                      accent: scheme.tertiary,
                    ),
                  if (template.hasMitAuflistung)
                    AuflistungBadge(
                      label: 'mit Auflistung',
                      accent: scheme.primary,
                    ),
                  if (!template.hasOhneAuflistung && !template.hasMitAuflistung)
                    AuflistungBadge(
                      label: 'keine Datei',
                      accent: scheme.error,
                    ),
                ],
              ),
            ),
            // Felder
            Expanded(
              flex: flexFields,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$fieldCount ${fieldCount == 1 ? 'Feld' : 'Felder'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (requiredCount > 0)
                    Text(
                      'davon $requiredCount Pflicht',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            // Aktionen
            SizedBox(
              width: actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => _navigateToDetails(context),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Vorlage bearbeiten',
                  ),
                  IconButton(
                    onPressed: () => _showDeleteDialog(context, template.id),
                    icon: const Icon(Icons.delete_outline),
                    color: scheme.error,
                    tooltip: 'Vorlage löschen',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToDetails(BuildContext context) async {
    final didChange = await context.router.push<bool>(
      FormTemplateDetailsRoute(formTemplate: template),
    );
    if (didChange == true && context.mounted) {
      context.read<FormTemplateOverviewBloc>().add(LoadFormTemplatesEvent());
    }
  }

  void _showDeleteDialog(BuildContext context, int templateId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Löschen bestätigen'),
          content: const Text(
            'Soll die Vorlage wirklich gelöscht werden? Diese Aktion kann nicht rückgängig gemacht werden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              // UX: Destructive action clearly marked with error colors
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                context.read<FormTemplateOverviewBloc>().add(
                  DeleteFormTemplateEvent(templateId: templateId),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );
  }
}
