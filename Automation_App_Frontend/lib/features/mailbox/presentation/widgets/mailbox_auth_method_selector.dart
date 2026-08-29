import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Wahl des Anmeldewegs für die Postfach-Überwachung: gewöhnliche
/// IMAP-Anmeldung mit Passwort (1&1/IONOS, Gmail) oder Outlook/Microsoft per
/// Browser-Anmeldung. Welcher Weg gilt, entscheidet allein, wo das Postfach
/// liegt — nicht, mit welchem Programm es sonst gelesen wird.
/// Gebunden an das Formularfeld `authMethod`.
class MailboxAuthMethodSelector extends StatelessWidget {
  const MailboxAuthMethodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ReactiveValueListenableBuilder<MailboxAuthMethod>(
      formControlName: 'authMethod',
      builder: (context, control, _) {
        final value = control.value ?? MailboxAuthMethod.appPassword;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text('Anmeldeweg', style: Theme.of(context).textTheme.labelLarge),
              SegmentedButton<MailboxAuthMethod>(
                segments: const [
                  ButtonSegment(
                    value: MailboxAuthMethod.appPassword,
                    icon: Icon(Icons.mail_outline),
                    label: Text('IMAP mit Passwort'),
                  ),
                  ButtonSegment(
                    value: MailboxAuthMethod.microsoftOAuth,
                    icon: Icon(Icons.window),
                    label: Text('Outlook / Microsoft'),
                  ),
                ],
                selected: {value},
                onSelectionChanged: (selection) =>
                    control.value = selection.first,
              ),
            ],
          ),
        );
      },
    );
  }
}
