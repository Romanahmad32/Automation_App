import 'package:flutter/material.dart';

/// Hinweis auf der Registerseite, solange überhaupt kein Vorgang erfasst ist.
///
/// Seit das Register alle Vorgänge führt (§6.2) heißt „leer" wörtlich leer —
/// vorher stand hier auch dann etwas, wenn Vorgänge liefen, aber noch keiner
/// abgeschlossen war.
class RegisterLeerHinweis extends StatelessWidget {
  const RegisterLeerHinweis({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Vorgänge erfasst. Sobald ein Vorgang angelegt wird, '
              'erscheint er hier als Registerzeile — die laufende Nummer '
              'bekommt er beim Abschluss.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
