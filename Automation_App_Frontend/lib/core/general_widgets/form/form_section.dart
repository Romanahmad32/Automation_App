import 'package:flutter/material.dart';

/// Karte mit Abschnittsüberschrift (Icon + Titel + optionale Erläuterung) für
/// eine thematische Gruppe von Formularfeldern. Wird sowohl von den
/// Einstellungen als auch von der Zentralruf-Anfrage genutzt, damit beide
/// Seiten dasselbe Erscheinungsbild haben.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  final IconData icon;
  final String title;

  /// Optionale Erläuterung unter der Überschrift.
  final String? subtitle;

  /// Optionales Widget rechts in der Kopfzeile (z. B. ein Schalter, der den
  /// Abschnitt aktiviert).
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Row(
              children: [
                // Icon in getöntem, abgerundetem Chip — hebt den Sektionskopf
                // hervor und bringt den blauen Akzent dezent ins Spiel.
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.bodySmall),
            ...children,
          ],
        ),
      ),
    );
  }
}
