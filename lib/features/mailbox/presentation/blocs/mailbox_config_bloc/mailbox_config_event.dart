part of 'mailbox_config_bloc.dart';

sealed class MailboxConfigEvent extends Equatable {
  const MailboxConfigEvent();

  @override
  List<Object?> get props => [];
}

final class LoadMailboxConfigEvent extends MailboxConfigEvent {
  const LoadMailboxConfigEvent();
}

final class SaveMailboxConfigEvent extends MailboxConfigEvent {
  final MailboxConfigUpdate update;

  const SaveMailboxConfigEvent(this.update);

  @override
  List<Object?> get props => [update];
}

/// Startet die Microsoft-Anmeldung (Outlook): Das Backend öffnet den Browser
/// und übernimmt bei Erfolg Konto und Server automatisch.
final class MicrosoftSignInEvent extends MailboxConfigEvent {
  const MicrosoftSignInEvent();
}

/// Meldet das Microsoft-Konto ab (entfernt die gespeicherten Tokens).
final class MicrosoftSignOutEvent extends MailboxConfigEvent {
  const MicrosoftSignOutEvent();
}
