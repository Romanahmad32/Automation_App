/// Zustände der Datensicherung (Export/Import).
sealed class BackupState {
  const BackupState();
}

/// Bereit — keine laufende Aktion.
class BackupIdle extends BackupState {
  const BackupIdle();
}

/// Export oder Import läuft; [meldung] beschreibt den aktuellen Schritt.
class BackupBusy extends BackupState {
  final String meldung;

  const BackupBusy(this.meldung);
}

/// Aktion erfolgreich abgeschlossen; [meldung] ist die Rückmeldung an den Nutzer.
class BackupErfolg extends BackupState {
  final String meldung;

  const BackupErfolg(this.meldung);
}

/// Aktion fehlgeschlagen; [meldung] erläutert den Fehler.
class BackupFehler extends BackupState {
  final String meldung;

  const BackupFehler(this.meldung);
}
