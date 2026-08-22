import 'package:flutter/material.dart';

/// Hinweis auf der Registerseite, solange noch kein Vorgang abgeschlossen —
/// und damit noch keine Registerzeile entstanden — ist.
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
              'Noch keine abgeschlossenen Vorgänge. Sobald ein Vorgang im '
              'Word-Schritt abgeschlossen wird, erscheint er hier als '
              'Registerzeile.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
