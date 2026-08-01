import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:flutter/material.dart';

/// Auswahl der Auflistungs-Version und des Vorsteuer-Status für die aktuelle
/// Vorlage.
class WizardOptionsCard extends StatelessWidget {
  final FormTemplate template;
  final bool mitAuflistung;
  final bool vorsteuerabzugsberechtigt;
  final ValueChanged<bool> onMitAuflistungChanged;
  final ValueChanged<bool> onVorsteuerChanged;

  const WizardOptionsCard({
    super.key,
    required this.template,
    required this.mitAuflistung,
    required this.vorsteuerabzugsberechtigt,
    required this.onMitAuflistungChanged,
    required this.onVorsteuerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versionHinweis = !template.hasMitAuflistung
        ? 'Keine Version mit Auflistung hinterlegt.'
        : !template.hasOhneAuflistung
        ? 'Nur eine Version mit Auflistung hinterlegt.'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('Mit Auflistung (Schadensaufstellung)'),
              subtitle: Text(
                versionHinweis ??
                    'Fügt einen Schritt für Schadenspositionen und die '
                        'RVG-Kostenberechnung hinzu.',
                style: versionHinweis != null
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
              value: mitAuflistung,
              onChanged: (value) => onMitAuflistungChanged(value ?? false),
            ),
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('Mandant ist vorsteuerabzugsberechtigt'),
              subtitle: const Text(
                'Kreuzt im Dokument "ist / ist nicht vorsteuerabzugsberechtigt" '
                'an und steuert die RVG-Umsatzsteuer.',
              ),
              value: vorsteuerabzugsberechtigt,
              onChanged: (value) => onVorsteuerChanged(value ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
