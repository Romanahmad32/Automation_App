import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Outlook-Weg: statt App-Passwort eine einmalige Microsoft-Anmeldung im
/// Browser. Zeigt je nach Zustand den Anmelde-Knopf, das angemeldete Konto
/// (mit Abmelden) oder — solange die Azure-Client-ID fehlt — einen Hinweis für
/// den Entwickler (docs/OUTLOOK_SETUP.md).
class MailboxMicrosoftSignInSection extends StatelessWidget {
  final MailboxConfig config;

  /// True, während die Anmeldung im Browser läuft.
  final bool signInPending;

  const MailboxMicrosoftSignInSection({
    super.key,
    required this.config,
    required this.signInPending,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.account_circle,
      title: 'Microsoft-Konto',
      subtitle:
          'Outlook-Postfächer erlauben kein App-Passwort mehr. Stattdessen '
          'einmal mit dem Microsoft-Konto anmelden — es öffnet sich das '
          'normale Anmeldefenster im Browser. Die Anmeldung bleibt danach '
          'dauerhaft gültig.',
      children: [buildContent(context)],
    );
  }

  Widget buildContent(BuildContext context) {
    if (!config.microsoftAuthAvailable) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.info_outline),
        title: Text('Microsoft-Anmeldung noch nicht eingerichtet'),
        subtitle: Text(
          'Es fehlt die Azure-Client-ID in den Servereinstellungen '
          '(Mailbox:MicrosoftClientId). Einrichtung: docs/OUTLOOK_SETUP.md.',
        ),
      );
    }

    if (signInPending) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Anmeldefenster im Browser geöffnet …'),
        subtitle: Text(
          'Bitte dort mit der Outlook-Adresse und dem normalen '
          'Kontopasswort anmelden.',
        ),
      );
    }

    final account = config.microsoftAccount;
    if (account != null && account.isNotEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(account),
        subtitle: const Text('Angemeldet — das Postfach wird überwacht.'),
        trailing: TextButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Abmelden'),
          onPressed: () =>
              context.read<MailboxConfigBloc>().add(const MicrosoftSignOutEvent()),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        icon: const Icon(Icons.login),
        label: const Text('Mit Microsoft anmelden'),
        onPressed: () =>
            context.read<MailboxConfigBloc>().add(const MicrosoftSignInEvent()),
      ),
    );
  }
}
