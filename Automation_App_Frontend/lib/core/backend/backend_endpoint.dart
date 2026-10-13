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

  /// Vorgabe 5143; der E2E-Testmodus läuft auf einem eigenen Port
  /// (`--dart-define=AUTOMATION_BACKEND_PORT=5243`), damit er nie an den Dienst
  /// der installierten Anwendung gerät.
  static const int port = int.fromEnvironment(
    'AUTOMATION_BACKEND_PORT',
    defaultValue: 5143,
  );

  /// Gesetzt per `--dart-define=AUTOMATION_TESTMODUS=true`: die Anwendung
  /// arbeitet dann nur mit einem Dienst, der selbst „Testmodus“ meldet
  /// (siehe `BackendLauncher`).
  static const bool testmodusErwartet = bool.fromEnvironment(
    'AUTOMATION_TESTMODUS',
  );

  static const String basisUrl = 'http://$host:$port';
  static const String healthUrl = '$basisUrl/health';
  static const String mailboxHubUrl = '$basisUrl/hubs/mailbox';
  static const String registerHubUrl = '$basisUrl/hubs/register';

  /// Kurzform für Meldungen an den Anwender.
  static const String adresse = '$host:$port';
}
