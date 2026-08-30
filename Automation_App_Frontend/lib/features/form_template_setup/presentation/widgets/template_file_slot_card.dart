import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_placeholders_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Karte für eine der beiden Word-Dateien (ohne/mit Auflistung): Dateiauswahl,
/// erkannte Platzhalter und – beim Mit-Slot – die Warnung, falls
/// {{Schadensaufstellung}} fehlt.
class TemplateFileSlotCard extends StatelessWidget {
  final TemplateFileSlot slot;
  final String? path;
  final String title;
  final String subtitle;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final ValueChanged<String> onPlaceholderSelected;

  /// Die aktuell eingetragenen Feldnamen — durchgereicht an die Chips
  /// (Optik „übernommen", Zählzeile, „Alle übernehmen"; #35 Teil 3).
  final Iterable<String?> vorhandeneNamen;

  final void Function(List<String> placeholders)? onAlleUebernehmen;

  const TemplateFileSlotCard({
    super.key,
    required this.slot,
    required this.path,
    required this.title,
    required this.subtitle,
    required this.onPick,
    required this.onRemove,
    required this.onPlaceholderSelected,
    this.vorhandeneNamen = const [],
    this.onAlleUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMitSlot = slot == TemplateFileSlot.mitAuflistung;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(subtitle, style: theme.textTheme.bodySmall),
            Row(
              spacing: 10,
              children: [
                Icon(
                  Icons.description,
                  color: theme.colorScheme.primaryContainer,
                ),
                Expanded(
                  child: Text(
                    path ?? 'Keine Word-Datei verknüpft',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (path != null)
                  IconButton(
                    tooltip: 'Verknüpfung entfernen',
                    icon: const Icon(Icons.close),
                    onPressed: onRemove,
                  ),
                CustomRectangularButton(
                  icon: const Icon(Icons.file_open),
                  label: Text(
                    path == null
                        ? 'Word-Datei verknüpfen'
                        : 'Andere Datei wählen',
                  ),
                  onPressed: onPick,
                ),
              ],
            ),
            if (isMitSlot && path != null)
              BlocBuilder<TemplatePlaceholdersBloc, TemplatePlaceholdersState>(
                builder: (context, placeholdersState) {
                  final result = placeholdersState.forSlot(
                    TemplateFileSlot.mitAuflistung,
                  );
                  final missingPlaceholder =
                      result is SlotPlaceholdersLoaded &&
                      !result.placeholders.any(
                        (p) => p.toLowerCase() == 'schadensaufstellung',
                      );
                  if (!missingPlaceholder) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    spacing: 10,
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.amber),
                      Expanded(
                        child: Text(
                          'Die verknüpfte Word-Datei enthält keinen Platzhalter '
                          '{{Schadensaufstellung}}. Ohne diesen Platzhalter '
                          'schlägt die Dokumenterstellung mit Auflistung fehl.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  );
                },
              ),
            if (path != null)
              TemplatePlaceholdersView(
                slot: slot,
                onPlaceholderSelected: onPlaceholderSelected,
                vorhandeneNamen: vorhandeneNamen,
                onAlleUebernehmen: onAlleUebernehmen,
              ),
          ],
        ),
      ),
    );
  }
}
