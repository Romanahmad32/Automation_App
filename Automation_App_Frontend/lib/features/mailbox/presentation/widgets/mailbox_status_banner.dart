import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_datetime_format.dart';
import 'package:flutter/material.dart';

/// Statuszeile: verbunden / inaktiv / Fehler, plus letzter Empfang.
class MailboxStatusBanner extends StatelessWidget {
  final MailboxStatus status;
  final String? error;

  const MailboxStatusBanner({
    super.key,
    required this.status,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color accent, IconData icon, String text) = switch (status) {
      _ when error != null => (
        theme.colorScheme.error,
        Icons.error_outline,
        error!,
      ),
      MailboxStatus(connected: true) => (
        Colors.green,
        Icons.cloud_done,
        'Verbunden — eingehende Antworten werden automatisch erfasst'
            '${status.idleSupported ? ' (Push/IDLE)' : ' (Abruf-Modus)'}.',
      ),
      MailboxStatus(enabled: false) => (
        theme.colorScheme.outline,
        Icons.cloud_off,
        'Überwachung ausgeschaltet. In den Einstellungen unter '
            '"E-Mail" aktivieren.',
      ),
      MailboxStatus(configured: false) => (
        theme.colorScheme.tertiary,
        Icons.key_off,
        'Kein Postfach-Zugang hinterlegt. In den Einstellungen unter '
            '"E-Mail" einrichten.',
      ),
      _ when status.lastError != null => (
        theme.colorScheme.error,
        Icons.sync_problem,
        'Verbindung unterbrochen: ${status.lastError}. Es wird automatisch '
            'erneut verbunden.',
      ),
      _ => (
        theme.colorScheme.tertiary,
        Icons.sync,
        'Überwachung eingeschaltet — verbinde …',
      ),
    };

    final tone = SoftTone.fromAccent(accent, theme.colorScheme);
    return Container(
      width: double.infinity,
      color: tone.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: tone.foreground, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: tone.foreground)),
          ),
          if (status.lastReplyAt case final last?) ...[
            const SizedBox(width: 12),
            Text(
              'Letzter Empfang: ${formatMailboxDateTime(last)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tone.foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
