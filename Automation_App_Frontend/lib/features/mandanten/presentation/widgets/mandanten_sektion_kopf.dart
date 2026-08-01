import 'package:flutter/material.dart';

/// Kopfzeile der Mandanten-Sektion mit Titel und Trefferzähler (gefiltert vs.
/// gesamt, je nach aktiver Suche).
class MandantenSektionKopf extends StatelessWidget {
  final int anzahl;
  final int gesamt;
  final String query;

  const MandantenSektionKopf({
    super.key,
    required this.anzahl,
    required this.gesamt,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = query.trim().isEmpty
        ? '$anzahl ${anzahl == 1 ? 'Mandant' : 'Mandanten'}'
        : '$anzahl von $gesamt Mandanten';
    return Row(
      children: [
        Icon(
          Icons.people_alt_outlined,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Mandanten',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
