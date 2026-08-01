import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_datetime_format.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_reply_empty_hint.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/zwischennachricht_badge.dart';
import 'package:flutter/material.dart';

/// Linke Spalte: Button „Manuell einfügen", Überschrift und die Liste der
/// automatisch erfassten Zentralruf-Antworten.
class MailboxReplyList extends StatelessWidget {
  final List<ReceivedReply> replies;
  final String? selectedId;
  final bool manualSelected;
  final bool loading;
  final MailboxStatus status;
  final ValueChanged<String> onSelect;
  final VoidCallback onManual;

  const MailboxReplyList({
    super.key,
    required this.replies,
    required this.selectedId,
    required this.manualSelected,
    required this.loading,
    required this.status,
    required this.onSelect,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: manualSelected
              ? FilledButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manuell einfügen'),
                  onPressed: onManual,
                )
              : FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manuell einfügen'),
                  onPressed: onManual,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Text(
                'Erfasste Antworten',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : replies.isEmpty
              ? MailboxReplyEmptyHint(status: status)
              : ListView.separated(
                  itemCount: replies.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final reply = replies[index];
                    final data = reply.data;
                    final zwischennachricht = data.zwischennachricht;
                    final hatWarnung =
                        !zwischennachricht &&
                        (reply.warnings.isNotEmpty ||
                            data.keinVersichererErmittelt);
                    return ListTile(
                      selected: reply.id == selectedId,
                      selectedTileColor: theme.colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                      leading: Icon(
                        zwischennachricht
                            ? Icons.hourglass_top
                            : hatWarnung
                            ? Icons.warning_amber
                            : Icons.mark_email_unread,
                        color: zwischennachricht || hatWarnung
                            ? theme.colorScheme.tertiary
                            : null,
                      ),
                      title: Text(
                        data.referenz ??
                            data.versichererName ??
                            '(ohne Referenz)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data.versichererName ?? 'Versicherer unbekannt'}'
                            ' · ${formatMailboxDateTime(reply.receivedAt)}',
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
                      onTap: () => onSelect(reply.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
