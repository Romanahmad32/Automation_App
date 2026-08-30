import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:flutter/material.dart';

/// Stellt eine Akte (Ordner) eines Mandanten mit ihren Fällen dar; pro Fall die
/// Anzahl Dokumente in Klammern.
class AkteBlock extends StatelessWidget {
  final Akte akte;

  const AkteBlock({super.key, required this.akte});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder, size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  akte.ordnername,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!akte.faelleGeladen)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                'Fälle werden gelesen …',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            )
          else if (akte.faelle.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2),
              child: Text(
                'Keine Fälle in diesem Ordner.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            )
          else
            for (final fall in akte.faelle)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 2),
                child: Text(
                  '• ${fall.name}'
                  '${fall.dokumente.isEmpty ? '' : '  (${fall.dokumente.length})'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
        ],
      ),
    );
  }
}
