import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:flutter/material.dart';

/// Zeigt die Vorlage so, **wie sie hinterlegt ist** — mit ihren Platzhaltern,
/// nicht gefüllt (§4.7).
///
/// Der Gegenpol zur Platzhalter-Übersicht: Die sagt, was herauskam, dieser
/// Dialog sagt, was dasteht. Zusammen ist ein gefüllter Text wieder auf seine
/// Vorlage zurückzuführen, ohne die Einstellungen aufzumachen.
class VorlagentextDialog extends StatelessWidget {
  final MailVorlage vorlage;

  const VorlagentextDialog({super.key, required this.vorlage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final betreff = vorlage.betreff.trim();

    return AlertDialog(
      title: Text(vorlage.name),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(
                'So ist die Vorlage hinterlegt.',
                style: theme.textTheme.bodySmall,
              ),
              Text('Betreff', style: theme.textTheme.labelLarge),
              SelectableText(
                betreff.isEmpty ? 'Ohne Betreffzeile' : betreff,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              Text('Text', style: theme.textTheme.labelLarge),
              SelectableText(
                vorlage.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
