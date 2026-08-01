part of 'zentralruf_reply_bloc.dart';

sealed class ZentralrufReplyState extends Equatable {
  const ZentralrufReplyState();

  @override
  List<Object?> get props => [];
}

class ZentralrufReplyInitial extends ZentralrufReplyState {}

class ZentralrufReplyLoading extends ZentralrufReplyState {}

class ZentralrufReplyParsed extends ZentralrufReplyState {
  final ZentralrufReplyParseResult result;

  const ZentralrufReplyParsed(this.result);

  @override
  List<Object?> get props => [result];
}

class ZentralrufReplyError extends ZentralrufReplyState {
  final String message;

  const ZentralrufReplyError(this.message);

  @override
  List<Object?> get props => [message];
}
