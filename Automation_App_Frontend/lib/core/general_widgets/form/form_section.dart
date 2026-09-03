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
    this.hervorgehoben = false,
    required this.children,
  });

  final IconData icon;
  final String title;

  /// Optionale Erläuterung unter der Überschrift.
  final String? subtitle;

  /// Optionales Widget rechts in der Kopfzeile (z. B. ein Schalter, der den
  /// Abschnitt aktiviert).
  final Widget? trailing;

  /// Hebt die Karte hervor, solange in ihr etwas offen ist, das sonst
  /// untergeht — etwa Eingaben, die nur im Formular stehen. Standard ist
  /// `false`: Betonung, die immer da ist, betont nichts.
  final bool hervorgehoben;

  final List<Widget> children;

  /// Dieselbe Form wie die ruhige Karte, nur mit kräftigerem Rand in der
  /// Akzentfarbe. Über `copyWith` auf die Form aus dem `cardTheme` statt neu
  /// gebaut, damit ein dort geänderter Radius auch hier ankommt; `null` heißt
  /// „nichts überschreiben" und lässt der Karte ihr Standardaussehen.
  ShapeBorder? _kartenform(ThemeData theme) {
    if (!hervorgehoben) return null;
    final rand = BorderSide(color: theme.colorScheme.primary, width: 2);
    final standard = theme.cardTheme.shape;
    return standard is RoundedRectangleBorder
        ? standard.copyWith(side: rand)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: rand,
          );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: _kartenform(theme),
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
                ?trailing,
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
