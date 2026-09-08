import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_zeile.dart';
import 'package:flutter/material.dart';

/// Der Herkunftskasten im Bearbeiten-Dialog einer historischen Zeile: die
/// Freitextzelle, wie sie im Registerbuch steht, die Selbsteinschätzung der
/// Übernahme, die Befunde und die Anmerkungen des Erzeugers.
///
/// Der **Freitext ist der Beleg**: Die Felder darunter sind die Zerlegung, und
/// ob sie stimmt, lässt sich nur an der Originalzeile prüfen. Ohne ihn wäre
/// nicht zu erkennen, *was* zu berichtigen wäre. Derselbe Gedanke wie im
/// Mandanten-Import (`ImportEintragDialog`).
class HistorieHerkunftKasten extends StatelessWidget {
  final RegisterHistorieZeile zeile;

  const HistorieHerkunftKasten({super.key, required this.zeile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Im Registerbuch: ${zeile.freitext}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Übernahme: ${zeile.sicherheitText}.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
          for (final befund in zeile.befunde)
            Text(
              befund,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          for (final hinweis in zeile.hinweise)
            Text(
              hinweis,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
            ),
        ],
      ),
    );
  }
}
