import 'dart:convert';

import 'package:automation_app/core/backend/app_version.dart';

/// Was `GET /health` des Dienstes meldet, sobald er bereit ist.
///
/// [testmodus] sagt, ob der Dienst im gefahrlosen E2E-Testmodus läuft (eigener
/// Datenordner, Attrappen statt Zentralruf, Versand, Entwurf und Druck). Ein
/// älterer Dienst kennt das Feld nicht — dann gilt er als „kein Testmodus".
class BackendGesundheit {
  const BackendGesundheit({required this.version, required this.testmodus});

  /// Die gemeldete Version, oder [AppVersion.unbekannt].
  final String version;
  final bool testmodus;

  /// Liest den Antwortkörper von `/health`.
  ///
  /// 200 ist die Zusage „bereit". Ist der Körper unlesbar, ändert das daran
  /// nichts — die Anwendung darf starten, nur die Anzeige weiß es nicht; ein
  /// unlesbarer Körper heißt aber auch nie „Testmodus".
  static BackendGesundheit ausKoerper(String koerper) {
    try {
      final json = jsonDecode(koerper);
      if (json is Map<String, dynamic>) {
        final version = json['version'];
        return BackendGesundheit(
          version: version is String && version.isNotEmpty
              ? version
              : AppVersion.unbekannt,
          testmodus: json['testmodus'] == true,
        );
      }
    } on FormatException {
      // fällt unten auf "unbekannt" zurück
    }
    return const BackendGesundheit(
      version: AppVersion.unbekannt,
      testmodus: false,
    );
  }
}
