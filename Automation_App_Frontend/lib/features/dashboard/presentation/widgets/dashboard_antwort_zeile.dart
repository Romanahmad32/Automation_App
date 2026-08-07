import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_datetime_format.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/zwischennachricht_badge.dart';
import 'package:flutter/material.dart';

/// Eine Zeile der Karte „Unbearbeitete Antworten": der noch nicht quittierte
/// Postfach-Treffer mit Referenz, Versicherer und Eingangszeit. Die Symbolik
/// entspricht der Liste im Postfach ([MailboxReplyList]) — Zwischennachricht
/// und Warnungen sind schon hier erkennbar.
class DashboardAntwortZeile extends StatelessWidget {
  final ReceivedReply antwort;

  /// Öffnet den Treffer im Postfach.
  final VoidCallback onOeffnen;

  const DashboardAntwortZeile({
    super.key,
    required this.antwort,
    required this.onOeffnen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = antwort.data;
    final zwischennachricht = data.zwischennachricht;
    final hatWarnung =
        !zwischennachricht &&
        (antwort.warnings.isNotEmpty || data.keinVersichererErmittelt);

    return ListTile(
      dense: true,
      leading: Icon(
        zwischennachricht
            ? Icons.hourglass_top
            : hatWarnung
            ? Icons.warning_amber
            : Icons.mark_email_unread,
        color: zwischennachricht || hatWarnung
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary,
      ),
      title: Text(
        data.referenz ?? data.versichererName ?? '(ohne Referenz)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.versichererName ?? 'Versicherer unbekannt'}'
            ' · ${formatMailboxDateTime(antwort.receivedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (zwischennachricht)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: ZwischennachrichtBadge(),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onOeffnen,
    );
  }
}
