import 'package:flutter/material.dart';

/// Die kleine, getönte Pille, mit der eine Registerzeile ihren Zustand zeigt —
/// Vorgangsstatus, „Historie", ein Befund.
///
/// Eigener Baustein, weil es drei davon gibt und sie in derselben Tabellenzelle
/// nebeneinanderstehen: Wären es drei Fassungen desselben `Container`, würde die
/// nächste Änderung an Rundung, Polster oder Schrift zwei davon treffen und die
/// dritte stehen lassen.
class StatusPille extends StatelessWidget {
  final String text;

  /// Die Akzentfarbe; Fläche und Rand leiten sich daraus ab.
  final Color farbe;

  /// Erklärung beim Verweilen — etwa die Befundsätze einer historischen Zeile.
  final String? tooltip;

  const StatusPille({
    super.key,
    required this.text,
    required this.farbe,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final pille = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: farbe.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: farbe,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    return tooltip == null ? pille : Tooltip(message: tooltip!, child: pille);
  }
}
