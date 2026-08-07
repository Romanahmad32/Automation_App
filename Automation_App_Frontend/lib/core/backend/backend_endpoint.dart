/// Adresse des lokalen Dienstes — die einzige Stelle im Frontend, an der Host
/// und Port stehen.
///
/// Vorher stand `localhost:5143` an drei Stellen im Code und ein viertes Mal in
/// `Properties/launchSettings.json` des Backends. Diese Streuung ist genau die
/// Art Fehler, die erst beim ausgelieferten Build auffällt: launchSettings gilt
/// nur für `dotnet run`, die veröffentlichte Exe lauscht ohne weitere
/// Konfiguration auf Port 5000.
abstract final class BackendEndpoint {
  static const String host = 'localhost';
  static const int port = 5143;

  static const String basisUrl = 'http://$host:$port';
  static const String healthUrl = '$basisUrl/health';
  static const String mailboxHubUrl = '$basisUrl/hubs/mailbox';

  /// Kurzform für Meldungen an den Anwender.
  static const String adresse = '$host:$port';
}
