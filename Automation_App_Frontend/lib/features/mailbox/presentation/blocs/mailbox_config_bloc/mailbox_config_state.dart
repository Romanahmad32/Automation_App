part of 'mailbox_config_bloc.dart';

sealed class MailboxConfigState extends Equatable {
  const MailboxConfigState();

  @override
  List<Object?> get props => [];
}

final class MailboxConfigLoading extends MailboxConfigState {
  const MailboxConfigLoading();
}

final class MailboxConfigLoaded extends MailboxConfigState {
  final MailboxConfig config;

  /// True direkt nach erfolgreichem Speichern (für eine Bestätigungsmeldung).
  final bool justSaved;

  /// True direkt nach erfolgreicher Microsoft-Anmeldung (eigene Meldung).
  final bool justSignedIn;

  const MailboxConfigLoaded(
    this.config, {
    this.justSaved = false,
    this.justSignedIn = false,
  });

  @override
  List<Object?> get props => [config, justSaved, justSignedIn];
}

/// Läuft, während sich der Nutzer im Browser bei Microsoft anmeldet — die
/// Maske zeigt derweil einen Hinweis statt eines generischen Ladekreises.
final class MailboxMicrosoftSignInPending extends MailboxConfigState {
  const MailboxMicrosoftSignInPending();
}

final class MailboxConfigError extends MailboxConfigState {
  final String message;

  const MailboxConfigError(this.message);

  @override
  List<Object?> get props => [message];
}
