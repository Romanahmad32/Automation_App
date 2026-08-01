import 'package:flutter/material.dart';

/// Kleiner Info-Chip (Icon + Label) für Kennzahlen einer Mandantenkarte,
/// z. B. Anzahl Akten oder Fälle.
class MandantInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const MandantInfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
