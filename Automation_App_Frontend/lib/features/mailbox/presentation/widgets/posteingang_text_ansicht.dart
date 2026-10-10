import 'package:flutter/material.dart';

/// Die Nur-Text-Fassung einer Nachricht (Issue #134) — auswählbar, damit ein
/// Textteil in eine Antwort oder ein Aktenvermerk übernommen werden kann.
class PosteingangTextAnsicht extends StatelessWidget {
  const PosteingangTextAnsicht({
    super.key,
    required this.text,
    this.gekuerzt = false,
  });

  final String text;

  /// True, wenn der Dienst den Text wegen seiner Größe **nicht** vollständig
  /// geholt hat — [text] trägt dann nur den Hinweis darauf, den diese Ansicht
  /// zusätzlich als eigene Zeile zeigt.
  final bool gekuerzt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gekuerzt) ...[
          Text(
            'Die Vorschau ist begrenzt. Den vollständigen Text findest du im '
            'Webmailer.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SelectableText(text.isEmpty ? '(Kein Mailtext)' : text),
      ],
    );
  }
}
