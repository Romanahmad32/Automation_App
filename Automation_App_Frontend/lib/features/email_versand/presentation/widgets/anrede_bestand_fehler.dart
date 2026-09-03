import 'package:flutter/material.dart';

/// Was an der Stelle der Chipreihe steht, wenn der **Anredebestand nicht
/// geladen** werden konnte (§4.7, §7.1, ergänzt am 02.09.2026).
///
/// **Der Mangel:** Ein Ladefehler sah aus wie ein leerer Bestand. Beides
/// führte zu `bausteine.isEmpty`, die Reihe verschwand ohne ein Wort, und
/// jede Mail nahm den festen Rückfall. Wer den Dienst gerade erst aktualisiert
/// hatte, suchte die Anredewahl in den Einstellungen — dort stand sie.
///
/// Getrennt vom leeren Bestand, der seine eigene Auskunft hat
/// ([AnredeBestandLeer]): Hier ist etwas kaputt und der Weg zurück gehört
/// dazu — erneut versuchen, ohne den Entwurf zu verlieren. Dort ist nichts
/// kaputt, und es gehört der Weg zum Anlegen dazu.
class AnredeBestandFehler extends StatelessWidget {
  final String fehler;
  final bool aktiv;
  final VoidCallback onErneut;

  const AnredeBestandFehler({
    super.key,
    required this.fehler,
    required this.onErneut,
    this.aktiv = true,
  });

  /// Der Fehlersatz samt Meldung des Dienstes. Getrennt herausgezogen, weil
  /// der **Wortlaut** die Prüfung ist und nicht das Aussehen.
  static String text(String fehler) =>
      'Die Anreden liessen sich nicht laden: $fehler';

  /// Was in der Zwischenzeit gilt. Seit dem 02.09.2026 ist das keine leere
  /// Zusage mehr: Der Rückfall folgt der Anredeart wie jeder gespeicherte
  /// Anfang — nur wählen lässt sich keiner.
  static const String rueckfallHinweis =
      'Solange gilt „Sehr geehrter/Sehr geehrte" wie ab Werk. Die Anredeart '
      'wirkt darauf, ein anderer Anfang lässt sich nicht wählen.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text('Anrede', style: theme.textTheme.labelLarge),
          Text(
            text(fehler),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          Text(
            rueckfallHinweis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: aktiv ? onErneut : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Erneut versuchen'),
            ),
          ),
        ],
      ),
    );
  }
}
