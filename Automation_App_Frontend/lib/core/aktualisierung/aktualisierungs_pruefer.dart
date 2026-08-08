import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/aktualisierung/aktualisierungs_ergebnis.dart';
import 'package:automation_app/core/aktualisierung/neue_version.dart';
import 'package:automation_app/core/aktualisierung/versions_vergleich.dart';

/// Fragt bei GitHub nach, ob es eine neuere Fassung gibt.
///
/// Die Anwendung aktualisiert sich **nicht** selbst — sie sagt nur Bescheid.
/// Installiert wird weiterhin über den Installer, weil nur der die laufende
/// Instanz sauber schließt und die Daten unter `%APPDATA%` unberührt lässt.
///
/// Ein Update-Hinweis ist eine Annehmlichkeit, keine Funktion, auf die sich
/// jemand verlässt: ohne Netz, hinter einer Kanzlei-Firewall oder bei einem
/// Ausfall von GitHub passiert schlicht nichts. Kein Fehlerdialog, kein
/// Protokolleintrag vor dem Anwender, keine Verzögerung des Starts.
class AktualisierungsPruefer {
  const AktualisierungsPruefer();

  /// Das Repository ist öffentlich, deshalb genügt eine anonyme Anfrage. Wird
  /// es einmal privat, liefert die API 404 und der Hinweis bleibt einfach aus.
  static const String repository = 'Romanahmad32/Automation_App';
  static const String releaseSeite =
      'https://github.com/$repository/releases/latest';
  static const String apiAdresse =
      'https://api.github.com/repos/$repository/releases/latest';

  /// Fragt nach. Jeder Fehler endet in [AktualisierungsErgebnis.nichtErreichbar].
  Future<AktualisierungsErgebnis> pruefen(
    String laufendeVersion, {
    Duration zeitlimit = const Duration(seconds: 5),
  }) async {
    final client = HttpClient()..connectionTimeout = zeitlimit;
    try {
      final anfrage = await client
          .getUrl(Uri.parse(apiAdresse))
          .timeout(zeitlimit);
      // Ohne User-Agent weist GitHub die Anfrage mit 403 ab.
      anfrage.headers.set(HttpHeaders.userAgentHeader, 'Automation-App');
      anfrage.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );

      final antwort = await anfrage.close().timeout(zeitlimit);
      if (antwort.statusCode != HttpStatus.ok) {
        await antwort.drain<void>();
        return const AktualisierungsErgebnis.nichtErreichbar();
      }
      final koerper = await antwort.transform(utf8.decoder).join();
      final neu = auswerten(koerper, laufendeVersion);
      return neu == null
          ? const AktualisierungsErgebnis.aktuell()
          : AktualisierungsErgebnis.verfuegbar(neu);
    } catch (_) {
      return const AktualisierungsErgebnis.nichtErreichbar();
    } finally {
      client.close(force: true);
    }
  }

  /// Der Teil, der ohne Netz prüfbar ist.
  ///
  /// `/releases/latest` lässt Entwürfe und Vorabversionen von sich aus aus —
  /// gemeldet wird also nur, was auch wirklich veröffentlicht ist.
  static NeueVersion? auswerten(String koerper, String laufendeVersion) {
    try {
      final daten = jsonDecode(koerper);
      if (daten is! Map<String, dynamic>) return null;

      final tag = daten['tag_name'];
      if (tag is! String) return null;
      if (!VersionsVergleich.istNeuer(tag, laufendeVersion)) return null;

      final seite = daten['html_url'];
      return NeueVersion(
        nummer: VersionsVergleich.teile(tag)!.join('.'),
        seite: seite is String && seite.isNotEmpty ? seite : releaseSeite,
      );
    } on FormatException {
      return null;
    }
  }
}
