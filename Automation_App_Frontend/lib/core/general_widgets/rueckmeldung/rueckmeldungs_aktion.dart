import 'package:flutter/material.dart';

/// Ein einzelner Knopf in einer Rückmeldung — „Erneut versuchen", „Rückgängig",
/// „Ordner öffnen".
///
/// Warum ein eigener Typ statt zweier Parameter (Text und Rückruf): So kann die
/// Meldung „mit Aktion" als *ein* Zustand behandelt werden — sie bleibt dann
/// länger stehen (`RueckmeldungsArt.mitAktionMindestens`), weil ein Knopf, der
/// verschwindet, bevor man ihn trifft, schlimmer ist als gar keiner.
@immutable
class RueckmeldungsAktion {
  const RueckmeldungsAktion({required this.text, required this.beiDruck});

  /// Aufschrift des Knopfes — ein Verb, das die Handlung nennt.
  final String text;

  /// Wird beim Druck aufgerufen; die Meldung schließt sich dabei selbst.
  final VoidCallback beiDruck;
}
