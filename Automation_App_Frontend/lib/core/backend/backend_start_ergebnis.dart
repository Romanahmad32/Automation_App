/// Wie der lokale Dienst zur Verfügung steht.
enum BackendStartStatus {
  /// Der Dienst lief bereits — beim Entwickeln der Normalfall (`dotnet run`).
  bereitsGestartet,

  /// Die Anwendung hat ihn selbst als Kindprozess gestartet.
  selbstGestartet,

  /// Er steht nicht zur Verfügung; die Anwendung ist ohne ihn nicht arbeitsfähig.
  fehlgeschlagen,
}

/// Ergebnis des Startversuchs samt Meldung für den Anwender.
class BackendStartErgebnis {
  const BackendStartErgebnis.bereitsGestartet()
    : status = BackendStartStatus.bereitsGestartet,
      meldung = null;

  const BackendStartErgebnis.selbstGestartet()
    : status = BackendStartStatus.selbstGestartet,
      meldung = null;

  const BackendStartErgebnis.fehlgeschlagen(this.meldung)
    : status = BackendStartStatus.fehlgeschlagen;

  final BackendStartStatus status;

  /// Nur im Fehlerfall gesetzt: Klartext, der dem Anwender angezeigt wird.
  final String? meldung;

  bool get erfolgreich => status != BackendStartStatus.fehlgeschlagen;
}
