part of 'mailbox_inbox_cubit.dart';

/// Zustand der Inbox-Ansicht: Verbindungsstatus und die erfassten Antworten.
/// Beide werden zusammen geladen, damit die Ansicht in einem Rutsch aktualisiert.
class MailboxInboxState extends Equatable {
  final bool loading;
  final MailboxStatus status;
  final List<ReceivedReply> replies;

  /// Fehlermeldung des letzten Ladeversuchs (z. B. Dienst nicht erreichbar).
  final String? error;

  const MailboxInboxState({
    this.loading = false,
    this.status = MailboxStatus.unknown,
    this.replies = const [],
    this.error,
  });

  MailboxInboxState copyWith({
    bool? loading,
    MailboxStatus? status,
    List<ReceivedReply>? replies,
    String? error,
    bool clearError = false,
  }) {
    return MailboxInboxState(
      loading: loading ?? this.loading,
      status: status ?? this.status,
      replies: replies ?? this.replies,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, status, replies, error];
}
