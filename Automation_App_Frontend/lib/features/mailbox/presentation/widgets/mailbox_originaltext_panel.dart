import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Aufklappbarer Originaltext der Mail: zum Nachlesen und zum Markieren/Kopieren
/// einzelner Angaben, falls das automatische Mapping etwas nicht erkannt hat.
class MailboxOriginaltextPanel extends StatelessWidget {
  final String? rawText;

  const MailboxOriginaltextPanel({super.key, required this.rawText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = rawText;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: ExpansionTile(
        leading: const Icon(Icons.article_outlined),
        title: const Text('Originaltext der Mail'),
        subtitle: Text(
          text == null
              ? 'Für diese Antwort nicht verfügbar.'
              : 'Zum Nachlesen und Kopieren aufklappen.',
          style: theme.textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: text == null
            ? const []
            : [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Alles kopieren'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Originaltext in die Zwischenablage kopiert.',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
      ),
    );
  }
}
