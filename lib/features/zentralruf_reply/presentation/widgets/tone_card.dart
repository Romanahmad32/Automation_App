import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:flutter/material.dart';

/// Farbig hinterlegte Hinweiskarte (Info/Warnung/Fehler) im weichen Ton der App.
/// Wiederverwendet in der Antwort-Auswertung: Vorgangsdaten-Formular und
/// Vorgang-Zuordnung.
class ToneCard extends StatelessWidget {
  final Color accent;
  final IconData? icon;
  final String text;

  const ToneCard({
    super.key,
    required this.accent,
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tone = SoftTone.fromAccent(accent, Theme.of(context).colorScheme);
    return Card(
      color: tone.background,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (icon case final icon?) ...[
              Icon(icon, color: tone.foreground),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(text, style: TextStyle(color: tone.foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
