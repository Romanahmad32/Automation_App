import 'package:flutter/material.dart';

/// Leerzustand der Mandantenübersicht, wenn weder Mandanten noch Akten
/// vorhanden sind.
class MandantenLeererZustand extends StatelessWidget {
  const MandantenLeererZustand({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'Noch keine Mandanten und keine Akten gefunden',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Legen Sie über „Neuer Mandant" einen Mandanten an oder hinterlegen '
            'Sie in den Einstellungen den Stammordner des Aktensystems.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
