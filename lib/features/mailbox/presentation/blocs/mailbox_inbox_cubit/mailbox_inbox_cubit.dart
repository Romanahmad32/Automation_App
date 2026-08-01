import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_push_notifier.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'mailbox_inbox_state.dart';

/// Versorgt die Inbox-Ansicht: lädt Status und erfasste Antworten und quittiert
/// einzelne Treffer. Der Monitor läuft im Backend (ereignisbasiert per IDLE) und
/// meldet neue Treffer/Statuswechsel per SignalR ([MailboxPushNotifier]) — darauf hin lädt
/// die Ansicht den Stand live nach, ohne dass der Anwalt „Aktualisieren" drücken
/// muss. Manuelles Aktualisieren bleibt als Rückfallebene erhalten.
@injectable
class MailboxInboxCubit extends Cubit<MailboxInboxState> {
  final MailboxRepository _repository;
  final MailboxPushNotifier _hub;
  StreamSubscription<void>? _replySub;
  StreamSubscription<void>? _statusSub;

  MailboxInboxCubit(this._repository, this._hub)
    : super(const MailboxInboxState()) {
    _replySub = _hub.onReplyReceived.listen((_) => refresh());
    _statusSub = _hub.onStatusChanged.listen((_) => refresh());
    _hub.ensureConnected();
  }

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, clearError: true));

    final statusResult = await _repository.getStatus();
    final repliesResult = await _repository.getReplies(
      includeAcknowledged: false,
    );

    final status = switch (statusResult) {
      Right(value: final value) => value,
      Left() => state.status,
    };

    switch (repliesResult) {
      case Right(value: final replies):
        emit(state.copyWith(loading: false, status: status, replies: replies));
      case Left(value: final failure):
        emit(
          state.copyWith(
            loading: false,
            status: status,
            error: failure.message,
          ),
        );
    }
  }

  /// Markiert einen Treffer als erledigt und blendet ihn aus der offenen Liste aus.
  Future<void> acknowledge(String id) async {
    final result = await _repository.acknowledge(id);
    switch (result) {
      case Right():
        emit(
          state.copyWith(
            replies: state.replies.where((reply) => reply.id != id).toList(),
          ),
        );
      case Left(value: final failure):
        emit(state.copyWith(error: failure.message));
    }
  }

  @override
  Future<void> close() {
    _replySub?.cancel();
    _statusSub?.cancel();
    return super.close();
  }
}
