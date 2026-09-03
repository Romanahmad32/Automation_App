import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:flutter/material.dart';

/// Auswahl, welche Fassungen des Schreibens geschrieben werden: die
/// Word-Datei, das daraus erzeugte PDF oder beide. Verwendet im Speicherschritt
/// für die Ablage in der Akte (§6.1) und für das Speichern an einem frei
/// gewählten Ort — [titel] sagt, um welches von beiden es geht.
class AblageFormatAuswahl extends StatelessWidget {
  final AblageFormat format;
  final ValueChanged<AblageFormat> onChanged;
  final String titel;

  const AblageFormatAuswahl({
    super.key,
    required this.format,
    required this.onChanged,
    this.titel = 'Was abgelegt wird',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AblageFormat>(
            segments: [
              for (final wert in AblageFormat.values)
                ButtonSegment(value: wert, label: Text(wert.bezeichnung)),
            ],
            selected: {format},
            onSelectionChanged: (auswahl) => onChanged(auswahl.first),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          format.mitPdf
              ? 'Das PDF wird dabei aus der Word-Datei erzeugt — das dauert '
                    'einen Moment.'
              : 'Nur die Word-Datei — die bearbeitbare Fassung, mit der der '
                    'Assistent weiterarbeitet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
