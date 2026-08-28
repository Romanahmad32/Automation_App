import 'package:flutter/material.dart';

/// Die Titelzeile des Versanddialogs: links, worum es geht, rechts die Adresse,
/// von der aus gesendet wird (§4.7).
///
/// „Wird gesendet von kanzlei@…" stand vorher als eigener Kasten über dem
/// Formular. Er war dauerhaft da, war so hoch wie eine Empfängerzeile und sagte
/// eine Zeile, die sich nie ändert. In der Titelzeile steht dieselbe Auskunft
/// und kostet keine Höhe — und in der Vorschau steht sie ohnehin noch einmal
/// unter „Von".
class EmailVersandTitel extends StatelessWidget {
  final String absender;

  const EmailVersandTitel({super.key, required this.absender});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Text('E-Mail versenden'),
        if (absender.isNotEmpty) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'von $absender',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
