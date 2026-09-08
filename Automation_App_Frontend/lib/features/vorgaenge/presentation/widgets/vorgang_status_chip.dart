import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:flutter/material.dart';

/// Kleiner farbiger Chip, der den [VorgangStatus] anzeigt. Die Farbe spiegelt
/// den Fortschritt im Lebenszyklus wider (angefragt → versendet).
///
/// Die Pille selbst kommt aus [StatusPille] — dieselbe Form tragen der Chip
/// „Historie" und der Befund-Chip daneben in derselben Tabellenzelle.
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
  Widget build(BuildContext context) => StatusPille(
    text: status.displayName,
    farbe: _farbe(Theme.of(context).colorScheme),
  );
}
