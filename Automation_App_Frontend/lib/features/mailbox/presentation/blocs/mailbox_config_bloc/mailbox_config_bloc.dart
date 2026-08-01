import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'mailbox_config_event.dart';

part 'mailbox_config_state.dart';

/// Lädt und speichert den Postfach-Zugang (Einstellungsmaske). Das Speichern
/// lässt das Backend den Monitor sofort mit den neuen Werten neu verbinden.
@injectable
class MailboxConfigBloc extends Bloc<MailboxConfigEvent, MailboxConfigState> {
  final MailboxRepository _repository;

  MailboxConfigBloc(this._repository) : super(const MailboxConfigLoading()) {
    on<LoadMailboxConfigEvent>(_onLoad);
    on<SaveMailboxConfigEvent>(_onSave);
    on<MicrosoftSignInEvent>(_onMicrosoftSignIn);
    on<MicrosoftSignOutEvent>(_onMicrosoftSignOut);
  }

  Future<void> _onLoad(LoadMailboxConfigEvent event,
      Emitter<MailboxConfigState> emit,) async {
    emit(const MailboxConfigLoading());
    final result = await _repository.getConfig();
    switch (result) {
      case Right(value: final config):
        emit(MailboxConfigLoaded(config));
      case Left(value: final failure):
        emit(MailboxConfigError(failure.message));
    }
  }

  Future<void> _onSave(SaveMailboxConfigEvent event,
      Emitter<MailboxConfigState> emit,) async {
    emit(const MailboxConfigLoading());
    final result = await _repository.saveConfig(event.update);
    switch (result) {
      case Right(value: final config):
        emit(MailboxConfigLoaded(config, justSaved: true));
      case Left(value: final failure):
        emit(MailboxConfigError(failure.message));
    }
  }

  Future<void> _onMicrosoftSignIn(MicrosoftSignInEvent event,
      Emitter<MailboxConfigState> emit,) async {
    // Eigener Wartezustand: Der Nutzer meldet sich derweil im Browser an.
    emit(const MailboxMicrosoftSignInPending());
    final result = await _repository.microsoftSignIn();
    switch (result) {
      case Right(value: final config):
        emit(MailboxConfigLoaded(config, justSignedIn: true));
      case Left(value: final failure):
        emit(MailboxConfigError(failure.message));
    }
  }

  Future<void> _onMicrosoftSignOut(MicrosoftSignOutEvent event,
      Emitter<MailboxConfigState> emit,) async {
    emit(const MailboxConfigLoading());
    final result = await _repository.microsoftSignOut();
    switch (result) {
      case Right(value: final config):
        emit(MailboxConfigLoaded(config));
      case Left(value: final failure):
        emit(MailboxConfigError(failure.message));
    }
  }
}
