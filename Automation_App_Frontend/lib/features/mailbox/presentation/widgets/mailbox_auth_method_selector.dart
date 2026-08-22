import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Wahl des E-Mail-Anbieters bzw. Anmeldewegs für die Postfach-Überwachung:
/// Gmail (App-Passwort) oder Outlook/Microsoft (Anmeldung im Browser).
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
              Text(
                'E-Mail-Anbieter',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              SegmentedButton<MailboxAuthMethod>(
                segments: const [
                  ButtonSegment(
                    value: MailboxAuthMethod.appPassword,
                    icon: Icon(Icons.mail_outline),
                    label: Text('Gmail (App-Passwort)'),
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
