/// Domain-Port für die Push-Anbindung des Register-Spiegels (§6.2 „Dass ein
/// PDF gerade entsteht, ist an der Oberfläche ablesbar").
///
/// Seit die PDF-Fassung nachgezogen wird, ist die Antwort auf
/// `POST .../register/export` da, bevor sie existiert. Das Backend meldet das
/// Fertigwerden über den Hub `/hubs/register` (`registerPdfFertig`). Anders
/// als beim Postfach (`MailboxPushNotifier`, nutzdatenfreie Signale) trägt
/// diese Meldung schon die Nutzdaten — `RegisterSpiegelDto` spricht ohnehin
/// dieselbe Sprache (`pdfPfad`/`pdfFehler`), ein Nachladen des ganzen
/// Zeilenbestands nur für einen Satz in der Spiegelleiste wäre Ballast.
///
/// Die konkrete SignalR-Anbindung liegt in der data-Schicht (`RegisterHub`),
/// nach demselben Muster wie `MailboxHub` — eigener Hub, weil das Register ein
/// anderer senkrechter Schnitt ist als das Postfach.
abstract class RegisterPushNotifier {
  /// Feuert, sobald das Backend eine erledigte oder ausgebliebene
  /// PDF-Umwandlung meldet — dieselben Felder wie in `RegisterSpiegelDto`:
  /// `fertig` ob jetzt eine PDF-Fassung neben der `.docx` liegt, `pdfPfad` ihr
  /// Pfad, `fehler` der Klartext, warum keine entstand.
  Stream<({bool fertig, String? pdfPfad, String? fehler})> get onPdfFertig;

  /// Baut die Verbindung einmalig auf (idempotent).
  Future<void> ensureConnected();

  /// Schließt die Verbindung und gibt die Ressourcen frei (Lifecycle der DI).
  Future<void> dispose();
}
