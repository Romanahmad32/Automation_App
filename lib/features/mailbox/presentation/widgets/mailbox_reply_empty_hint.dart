import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:flutter/material.dart';

/// Platzhalter in der Trefferliste, wenn (noch) keine Antworten erfasst sind.
class MailboxReplyEmptyHint extends StatelessWidget {
  final MailboxStatus status;

  const MailboxReplyEmptyHint({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              status.connected
                  ? 'Noch keine offenen Antworten. Neue Zentralruf-Mails '
                        'erscheinen hier automatisch.'
                  : 'Sobald ein Postfach-Zugang hinterlegt und die Überwachung '
                        'aktiv ist, erscheinen eingehende Antworten hier.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
