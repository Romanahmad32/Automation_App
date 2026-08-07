import 'package:flutter/material.dart';

/// Leerzustand einer Startseiten-Karte: erklärt, wodurch hier etwas erscheint,
/// statt nur eine leere Fläche zu zeigen.
class DashboardLeerHinweis extends StatelessWidget {
  final IconData icon;
  final String text;

  const DashboardLeerHinweis({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
