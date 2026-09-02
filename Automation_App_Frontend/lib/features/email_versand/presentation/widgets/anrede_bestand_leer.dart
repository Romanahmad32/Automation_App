import 'package:flutter/material.dart';

/// Was an der Stelle der Chipreihe steht, wenn **keine Anrede angelegt** ist
/// (§4.7, §7.1, ergänzt am 02.09.2026).
///
/// **Der Mangel:** Der leere Bestand galt als selbsterklärend — „wer alle
/// Anreden gelöscht hat, weiß es". Das war falsch. Gelöscht ist der Bestand,
/// nicht die Anredezeile: `Anredebaustein.rueckfall` schreibt weiter „Sehr
/// geehrter Herr Müller" in jede Mail. Die Reihe verschwand also, und die
/// Anrede blieb — genau die Lage, aus der die Frage kam, warum über den Mails
/// eine Anrede steht, die niemand angelegt hat.
///
/// Kein Sprung in die Einstellungen von hier: Der Versanddialog ist modal, und
/// ihn zu verlassen hiesse den Entwurf verwerfen. Der Weg steht deshalb als
/// Text da.
class AnredeBestandLeer extends StatelessWidget {
  const AnredeBestandLeer({super.key});

  /// Der Wortlaut. Getrennt herausgezogen, weil er die Prüfung ist und nicht
  /// das Aussehen — wie bei `AnredeBestandFehler.text`.
  static const String text =
      'Es ist keine Anrede angelegt. Die Mail beginnt trotzdem mit einer: '
      '„Sehr geehrter/Sehr geehrte" gilt wie ab Werk, und die Anredeart wirkt '
      'darauf. Einen anderen Anfang legt man unter Einstellungen ▸ E-Mail an.';

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
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
