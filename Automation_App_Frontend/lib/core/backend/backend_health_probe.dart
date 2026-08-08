import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/backend/app_version.dart';
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

  /// Die vom Dienst gemeldete Version, sobald er bereit ist — sonst `null`.
  ///
  /// Zwei Antworten in einer, weil der Startvorgang ohnehin bis zur
  /// Bereitschaft pollt: die Version fällt dabei ab, ohne dass jemand ein
  /// zweites Mal anfragen muss.
  Future<String?> versionWennBereit({
    Duration zeitlimit = const Duration(seconds: 2),
  }) async {
    final client = HttpClient()..connectionTimeout = zeitlimit;
    try {
      final anfrage = await client
          .getUrl(Uri.parse(BackendEndpoint.healthUrl))
          .timeout(zeitlimit);
      final antwort = await anfrage.close().timeout(zeitlimit);
      if (antwort.statusCode != HttpStatus.ok) {
        await antwort.drain<void>();
        return null;
      }
      final koerper = await antwort.transform(utf8.decoder).join();
      return _versionAus(koerper);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 200 ist die Zusage „bereit". Ist die Antwort dahinter unlesbar, ändert das
  /// daran nichts — die Anwendung darf starten, nur die Anzeige weiß es nicht.
  static String _versionAus(String koerper) {
    try {
      final json = jsonDecode(koerper);
      if (json is Map<String, dynamic>) {
        final version = json['version'];
        if (version is String && version.isNotEmpty) return version;
      }
    } on FormatException {
      // fällt unten auf "unbekannt" zurück
    }
    return AppVersion.unbekannt;
  }
}
