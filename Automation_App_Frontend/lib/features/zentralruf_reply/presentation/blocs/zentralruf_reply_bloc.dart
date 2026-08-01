import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'zentralruf_reply_event.dart';
part 'zentralruf_reply_state.dart';

@injectable
class ZentralrufReplyBloc
    extends Bloc<ZentralrufReplyEvent, ZentralrufReplyState> {
  final UseCase<ZentralrufReplyParseResult, ZentralrufReplyInput> _parseReply;

  ZentralrufReplyBloc(this._parseReply) : super(ZentralrufReplyInitial()) {
    on<ParseZentralrufReplyEvent>(_onParseReplyEvent);
    on<ResetZentralrufReplyEvent>((_, emit) => emit(ZentralrufReplyInitial()));
  }

  Future<void> _onParseReplyEvent(
    ParseZentralrufReplyEvent event,
    Emitter<ZentralrufReplyState> emit,
  ) async {
    emit(ZentralrufReplyLoading());

    final result = await _parseReply(event.input);
    switch (result) {
      case Left(value: final failure):
        emit(ZentralrufReplyError(failure.message));
      case Right(value: final parseResult):
        emit(ZentralrufReplyParsed(parseResult));
    }
  }
}
