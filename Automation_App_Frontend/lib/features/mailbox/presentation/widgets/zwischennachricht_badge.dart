import 'package:flutter/material.dart';

/// Kleines gelbes Badge für Zwischennachrichten des Zentralrufs: die Mail
/// enthält noch keine Auskunft, die endgültige Antwort folgt in einer
/// weiteren E-Mail. Wird in der Postfachliste an der Kachel angezeigt,
/// damit der Fall ohne Öffnen der Antwort erkennbar ist.
class ZwischennachrichtBadge extends StatelessWidget {
  const ZwischennachrichtBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_top,
            size: 14,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 4),
          // Flexible statt eines unbeschränkten Text: Das Badge sitzt in der
          // engen Trefferspalte (§ mailbox_reply_list.dart) — bei "Am
          // größten" (Issue #57) reicht dort der Platz nicht mehr für Icon
          // plus vollen Text. Ellipsis statt Umbruch: Ein Badge bleibt
          // einzeilig.
          Flexible(
            child: Text(
              'Zwischennachricht — Antwort folgt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
