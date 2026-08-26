import 'package:flutter/material.dart';

/// Sagt, warum „Senden" noch grau ist (§4.7).
///
/// Ein abgeblendeter Knopf ist eine Behauptung ohne Begründung. Der teuerste
/// Fall in der Beobachtung: Der Anwalt tippt die Adresse ein und drückt Senden,
/// ohne sie mit Eingabe übernommen zu haben — das Feld sieht ausgefüllt aus,
/// der Entwurf hat aber keinen Empfänger. Genau das steht hier im Klartext.
class EmailFehltNochHinweis extends StatelessWidget {
  /// Was noch fehlt, in der Reihenfolge, in der es auszufüllen ist.
  final List<String> punkte;

  const EmailFehltNochHinweis({super.key, required this.punkte});

  @override
  Widget build(BuildContext context) {
    if (punkte.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.edit_note,
            size: 20,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zum Senden fehlt noch:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                for (final punkt in punkte)
                  Text(
                    '· $punkt',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
