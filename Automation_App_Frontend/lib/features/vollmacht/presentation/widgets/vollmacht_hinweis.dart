import 'package:flutter/material.dart';

/// Eine stille Hinweiszeile im Vollmacht-Dialog: Symbol, umbrechender Text,
/// wahlweise Knöpfe darunter — in der Tertiärfarbe, weil nichts davon ein
/// Fehler ist, sondern etwas, das der Anwalt wissen muss, bevor er druckt
/// (kein Mandant zugeordnet, Tatdatum offen, Vorlage fehlt).
class VollmachtHinweis extends StatelessWidget {
  final IconData icon;
  final String text;
  final List<Widget> aktionen;

  const VollmachtHinweis({
    super.key,
    required this.icon,
    required this.text,
    this.aktionen = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = theme.colorScheme.tertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: farbe),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(color: farbe),
              ),
              if (aktionen.isNotEmpty) Wrap(spacing: 8, children: aktionen),
            ],
          ),
        ),
      ],
    );
  }
}
