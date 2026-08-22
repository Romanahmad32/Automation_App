/// Ausgang einer Ablage in der Akte (§6.1): abgelegt — oder eine Rückfrage.
///
/// Der Konflikt ist bewusst kein `Failure`: nichts ist schiefgegangen, es fehlt
/// nur eine Entscheidung des Anwalts (siehe [AblageStrategie]).
class AblageErgebnis {
  /// Pfad im Fall-Ordner: bei [konflikt] der bereits vorhandenen Datei, sonst
  /// der der abgelegten Kopie.
  final String zielpfad;

  /// True, wenn im Fall-Ordner schon eine gleichnamige Datei liegt und noch
  /// nichts geschrieben wurde.
  final bool konflikt;

  const AblageErgebnis.abgelegt(this.zielpfad) : konflikt = false;

  const AblageErgebnis.konfliktMit(this.zielpfad) : konflikt = true;
}
