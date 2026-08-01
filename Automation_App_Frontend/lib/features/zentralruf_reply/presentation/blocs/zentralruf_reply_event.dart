part of 'zentralruf_reply_bloc.dart';

sealed class ZentralrufReplyEvent extends Equatable {
  const ZentralrufReplyEvent();

  @override
  List<Object?> get props => [];
}

class ParseZentralrufReplyEvent extends ZentralrufReplyEvent {
  final ZentralrufReplyInput input;

  const ParseZentralrufReplyEvent(this.input);

  @override
  List<Object?> get props => [input];
}

/// Setzt die Auswertung auf den Anfangszustand zurück (leeres Eingabepanel),
/// z. B. um nach einer Übernahme eine weitere Mail manuell einzufügen.
class ResetZentralrufReplyEvent extends ZentralrufReplyEvent {
  const ResetZentralrufReplyEvent();
}
