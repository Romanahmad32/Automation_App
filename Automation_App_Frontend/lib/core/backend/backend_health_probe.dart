import 'dart:io';

import 'package:automation_app/core/backend/backend_endpoint.dart';

/// Fragt `GET /health` des lokalen Dienstes ab.
///
/// Bewusst mit dem nackten [HttpClient] statt mit Dio: die Prüfung läuft, bevor
/// die Dependency Injection steht — der Dienst muss ja erst erreichbar sein,
/// damit die Anwendung überhaupt etwas anzeigen kann.
///
/// 200 heißt „vollständig gestartet". Solange der Dienst noch migriert,
/// antwortet er mit 503; ein Verbindungsfehler heißt, dass er (noch) gar nicht
/// lauscht. Beide Fälle sind hier dasselbe: nicht bereit.
class BackendHealthProbe {
  const BackendHealthProbe();

  Future<bool> istBereit({
    Duration zeitlimit = const Duration(seconds: 2),
  }) async {
    final client = HttpClient()..connectionTimeout = zeitlimit;
    try {
      final anfrage = await client
          .getUrl(Uri.parse(BackendEndpoint.healthUrl))
          .timeout(zeitlimit);
      final antwort = await anfrage.close().timeout(zeitlimit);
      await antwort.drain<void>();
      return antwort.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
