/// Ausgang einer Ablage in der Akte (§6.1): abgelegt — oder eine Rückfrage.
///
/// Eine Ablage umfasst **alle Fassungen eines Schreibens** (Word, PDF oder
/// beide). Sie gelingt oder scheitert als Ganzes: einzeln entschieden liefen
/// die Namen der Fassungen auseinander („Brief (2).docx" neben „Brief.pdf"),
/// und ein Abbruch hinterließe die Akte halb beschrieben.
///
/// Der Konflikt ist bewusst kein `Failure`: nichts ist schiefgegangen, es fehlt
/// nur eine Entscheidung des Anwalts (siehe [AblageStrategie]).
class AblageErgebnis {
  /// Die abgelegten Kopien im Fall-Ordner. Bei einer Rückfrage leer — dann ist
  /// noch nichts geschrieben.
  final List<String> zielpfade;

  /// Die bereits vorhandenen Dateien, über die zu entscheiden ist. Leer, wenn
  /// abgelegt wurde.
  final List<String> konfliktPfade;

  const AblageErgebnis.abgelegt(this.zielpfade) : konfliktPfade = const [];

  const AblageErgebnis.konfliktMit(this.konfliktPfade) : zielpfade = const [];

  bool get konflikt => konfliktPfade.isNotEmpty;
}
