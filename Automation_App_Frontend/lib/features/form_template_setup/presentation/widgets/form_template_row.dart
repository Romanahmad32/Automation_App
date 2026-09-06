import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/vorlagen_kopie_cubit/vorlagen_kopie_cubit.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/auflistung_badge.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_table_layout.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_stand_kennzeichen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eine Zeile der Vorlagen-Tabelle: Name, hinterlegte Word-Dateien (als
/// [AuflistungBadge]), der Stand ([VorlagenStandKennzeichen]), Feldzahl und die
/// Aktionen (bearbeiten/duplizieren/löschen).
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
                    AuflistungBadge(label: 'keine Datei', accent: scheme.error),
                ],
              ),
            ),
            // Stand — was der Editor beim letzten Speichern festgehalten hat.
            // Im `Wrap` wie die Dateibadges: Der bindet seine Kinder an die
            // Spaltenbreite, statt sie bei angehobener Schrift (Issue #57)
            // darüber hinauslaufen zu lassen.
            Expanded(
              flex: flexStand,
              child: Wrap(
                children: [VorlagenStandKennzeichen(stand: template.stand)],
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
                    onPressed: () => _dupliziere(context),
                    icon: const Icon(Icons.content_copy),
                    tooltip: 'Duplizieren',
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

  /// „Duplizieren" — die Feldarbeit einer Vorlage noch einmal, unter neuem
  /// Namen und ohne die Word-Dateien (#104 Stufe 4).
  ///
  /// Die schon **geladene** Liste liefert die belegten Namen. Sie ist ohnehin
  /// da (die Zeile ist Teil davon), und sie zu befragen kostet keine Anfrage;
  /// die letzte Instanz bleibt der Dienst, der eine Dublette mit 409 abweist —
  /// die Meldung kommt dann über `VorlagenKopieCubit` als Rückmeldung an.
  void _dupliziere(BuildContext context) {
    final uebersicht = context.read<FormTemplateOverviewBloc>().state;
    final vorhandene = uebersicht is FormTemplateOverviewLoaded
        ? [for (final vorlage in uebersicht.formTemplates) vorlage.templateName]
        : [template.templateName];
    context.read<VorlagenKopieCubit>().dupliziere(
      template,
      vorhandeneNamen: vorhandene,
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, int templateId) async {
    final bloc = context.read<FormTemplateOverviewBloc>();
    final bestaetigt = await bestaetigen(
      context,
      icon: Icons.warning_rounded,
      titel: 'Löschen bestätigen',
      text:
          'Soll die Vorlage wirklich gelöscht werden? Diese Aktion kann nicht rückgängig gemacht werden.',
      bestaetigung: 'Löschen',
      destruktiv: true,
    );
    if (!bestaetigt) return;
    bloc.add(DeleteFormTemplateEvent(templateId: templateId));
  }
}
