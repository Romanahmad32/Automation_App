import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_ssl_switch.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Servereinstellungen für den App-Passwort-Weg (Standard: Gmail). Beim
/// Outlook-Weg entfällt diese Sektion — dort werden Host, Port und SSL beim
/// Anmelden automatisch gesetzt.
class MailboxGmailServerSection extends StatelessWidget {
  const MailboxGmailServerSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.dns,
      title: 'Server (Standard: Gmail)',
      subtitle:
          'Für Gmail unverändert lassen. Andere Anbieter mit App-Passwort: '
          'IMAP-Host, Port und Verschlüsselung anpassen.',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: GeneralTextField<String>(
                formControlName: 'host',
                labelText: 'IMAP-Host',
                validationMessages: {
                  ValidationMessage.required: (_) => 'Pflichtfeld',
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GeneralTextField<String>(
                formControlName: 'port',
                labelText: 'Port',
                keyboardType: TextInputType.number,
                validationMessages: {
                  ValidationMessage.required: (_) => 'Pflichtfeld',
                  ValidationMessage.number: (_) => 'Zahl',
                },
              ),
            ),
          ],
        ),
        const MailboxSslSwitch(),
      ],
    );
  }
}
