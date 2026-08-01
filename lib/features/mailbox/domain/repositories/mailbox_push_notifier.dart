/// Domain-Port für die Push-Anbindung des Postfach-Monitors.
///
/// Das Backend meldet nutzdatenfreie Signale, sobald eine neue Zentralruf-Antwort
/// erfasst wurde ([onReplyReceived]) oder sich der Verbindungszustand der
/// Überwachung ändert ([onStatusChanged]); die Oberfläche holt den konkreten
/// Stand anschließend per Repository nach. Die konkrete SignalR-Implementierung
/// liegt in der data-Schicht; die Präsentationsschicht kennt nur diesen Port.
abstract class MailboxPushNotifier {
  /// Feuert, sobald das Backend eine neu erfasste Antwort meldet.
  Stream<void> get onReplyReceived;

  /// Feuert, sobald sich der Verbindungsstatus der Überwachung ändert.
  Stream<void> get onStatusChanged;

  /// Baut die Verbindung einmalig auf (idempotent).
  Future<void> ensureConnected();

  /// Schließt die Verbindung und gibt die Ressourcen frei (Lifecycle der DI).
  Future<void> dispose();
}
