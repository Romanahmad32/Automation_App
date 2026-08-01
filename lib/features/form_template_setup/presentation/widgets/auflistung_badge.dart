import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:flutter/material.dart';

/// Dezenter Badge, der anzeigt, welche Auflistungs-Version hinterlegt ist.
/// Nutzt [SoftTone], damit der Hintergrund im Light-Mode hell getoent bleibt
/// (statt der fast schwarzen `*Container`-Farben des Themes).
class AuflistungBadge extends StatelessWidget {
  final String label;
  final Color accent;

  const AuflistungBadge({super.key, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final tone = SoftTone.fromAccent(accent, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tone.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
