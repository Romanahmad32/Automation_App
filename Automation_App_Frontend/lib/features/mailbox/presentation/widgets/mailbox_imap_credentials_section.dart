import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_password_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Zugangsdaten für den Weg „IMAP mit Passwort": Postfach-Adresse und
/// Passwort. Gebunden an die Formularfelder `username` und `appPassword`.
class MailboxImapCredentialsSection extends StatelessWidget {
  /// Ob bereits ein Passwort gespeichert ist (Feld darf dann leer bleiben).
  final bool appPasswordSet;

  const MailboxImapCredentialsSection({
    super.key,
    required this.appPasswordSet,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.alternate_email,
      title: 'Zugangsdaten',
      subtitle:
          'Bei 1&1/IONOS: die vollständige Adresse und das Passwort des '
          'Postfachs — dort gibt es kein App-Passwort. Bei Gmail: '
          '2-Faktor-Authentifizierung aktivieren und unter '
          'myaccount.google.com/apppasswords ein App-Passwort erzeugen. '
          'Das Passwort wird verschlüsselt auf diesem Rechner gespeichert '
          '(gebunden an die Windows-Anmeldung) und nie wieder angezeigt.',
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
