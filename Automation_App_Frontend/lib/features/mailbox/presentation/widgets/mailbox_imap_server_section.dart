import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_anbieter_voreinstellung.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_ssl_switch.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Servereinstellungen für den Weg „IMAP mit Passwort". Beim Outlook-Weg
/// entfällt diese Sektion — dort werden Host, Port und SSL beim Anmelden
/// automatisch gesetzt. Der SMTP-Server für den Versand wird aus dem IMAP-Host
/// abgeleitet und muss nirgends gepflegt werden.
class MailboxImapServerSection extends StatelessWidget {
  const MailboxImapServerSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.dns,
      title: 'Server',
      subtitle:
          'Für 1&1/IONOS und Gmail genügt ein Klick auf die Voreinstellung. '
          'Andere Anbieter: IMAP-Host, Port und Verschlüsselung von Hand '
          'eintragen — die Werte stehen beim Anbieter unter "E-Mail-Programm '
          'einrichten".',
      children: [
        const MailboxAnbieterVoreinstellung(),
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
