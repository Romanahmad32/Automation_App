import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:flutter/material.dart';

/// Karte „Referenz": zeigt die (automatisch erzeugte oder manuell bearbeitete)
/// Referenz-Vorschau. Bei manueller Bearbeitung erlaubt [onReset], wieder auf
/// die automatische Erzeugung umzuschalten.
class ReferenzSection extends StatelessWidget {
  final bool referenzManuallyEdited;
  final VoidCallback onReset;

  const ReferenzSection({
    super.key,
    required this.referenzManuallyEdited,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.bookmark_outline,
      title: 'Referenz',
      children: [
        GeneralTextField<String>(
          labelText: 'Referenz (Vorschau, bearbeitbar)',
          formControlName: 'referenz',
          inputDecoration: InputDecoration(
            helperText: referenzManuallyEdited
                ? 'Manuell bearbeitet – wird so übernommen.'
                : 'Wird automatisch aus den Feldern oben erzeugt.',
            helperMaxLines: 2,
            suffixIcon: referenzManuallyEdited
                ? IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Automatisch aus den Feldern erzeugen',
                    onPressed: onReset,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
