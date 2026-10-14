/// Welchen Zustand der Dialog „App aktualisieren“ zeigt (#196, Vorschau 2a–2e).
enum AktualisierungsDialogPhase {
  /// 2a — eine neue Version ist da: „Jetzt aktualisieren“.
  verfuegbar,

  /// 2b — der Dienst lädt; der Dialog lässt sich schließen.
  laedt,

  /// 2c — geladen und geprüft: Bestätigung vor dem Neustart.
  bereit,

  /// 2d — Laden, Prüfen oder Starten ging nicht; ruhig, nicht rot.
  fehler,

  /// 2e — der Installer läuft, die App geht gleich zu; keine Knöpfe mehr.
  schliesst,

  /// Keine neue Version in Sicht (noch nicht geprüft, aktuell, Dienst stumm).
  /// Kommt nur vor, wenn sich der Stand bei offenem Dialog ändert.
  ohneUpdate,
}
