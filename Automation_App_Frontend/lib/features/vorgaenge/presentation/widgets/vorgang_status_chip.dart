import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:flutter/material.dart';

/// Kleiner farbiger Chip, der den [VorgangStatus] anzeigt. Die Farbe spiegelt
/// den Fortschritt im Lebenszyklus wider (angefragt → versendet).
class VorgangStatusChip extends StatelessWidget {
  final VorgangStatus status;

  const VorgangStatusChip({super.key, required this.status});

  Color _farbe(ColorScheme scheme) {
    switch (status) {
      case VorgangStatus.angefragt:
        return scheme.outline;
      case VorgangStatus.beantwortet:
        return scheme.tertiary;
      case VorgangStatus.erstellt:
        return scheme.primary;
      case VorgangStatus.abgelegt:
        return scheme.secondary;
      case VorgangStatus.versendet:
        return Colors.green.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final farbe = _farbe(scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: farbe.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: farbe,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
