import 'package:flutter/material.dart';

/// Hinweis, dass kein Stammordner für das Aktensystem festgelegt ist und die
/// automatische Ablage daher nicht möglich ist (manuelles Speichern bleibt).
class KeinStammordnerHinweis extends StatelessWidget {
  const KeinStammordnerHinweis({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Kein Stammordner für das Aktensystem festgelegt. Hinterlegen Sie '
              'ihn in den Einstellungen, um Dokumente automatisch in die Akte '
              'abzulegen. Alternativ können Sie unten manuell speichern.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
