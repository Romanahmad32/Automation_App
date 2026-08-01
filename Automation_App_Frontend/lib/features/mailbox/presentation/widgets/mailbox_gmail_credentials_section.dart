import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_password_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Zugangsdaten für den Gmail-Weg (App-Passwort): Postfach-Adresse und
/// App-Passwort. Gebunden an die Formularfelder `username` und `appPassword`.
class MailboxGmailCredentialsSection extends StatelessWidget {
  /// Ob bereits ein App-Passwort gespeichert ist (Feld darf dann leer bleiben).
  final bool appPasswordSet;

  const MailboxGmailCredentialsSection({super.key, required this.appPasswordSet});

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.alternate_email,
      title: 'Zugangsdaten',
      subtitle:
          'Für Gmail: 2-Faktor-Authentifizierung aktivieren und unter '
          'myaccount.google.com/apppasswords ein App-Passwort erzeugen — '
          'dieses, nicht das Kontopasswort, gehört unten hinein.',
      children: [
        GeneralTextField<String>(
          formControlName: 'username',
          labelText: 'Postfach-Adresse (E-Mail)',
          keyboardType: TextInputType.emailAddress,
          validationMessages: {
            ValidationMessage.email: (_) =>
                'Bitte eine gültige E-Mail-Adresse eingeben',
          },
        ),
        MailboxPasswordField(alreadySet: appPasswordSet),
      ],
    );
  }
}
