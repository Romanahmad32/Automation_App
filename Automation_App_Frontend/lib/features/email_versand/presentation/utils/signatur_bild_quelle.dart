import 'package:automation_app/core/backend/backend_endpoint.dart';

/// Woher die Vorschau die Bilder der Signatur bekommt (§4.7).
///
/// Die formatierte Signatur selbst kommt bewusst nie ins Frontend — sie ist
/// zehntausende Zeichen Word-HTML, das die App weder anzeigen noch bearbeiten
/// kann. Ihre Bilder aber schon: Sie sind das, was der Anwalt in der Vorschau
/// sucht, wenn er wissen will, ob das Logo mitgeht. Der Dienst liefert sie
/// einzeln aus, die Vorschau lädt sie über diese Adresse.
abstract final class SignaturBildQuelle {
  /// Getrennt vom Rest der Adresse, damit der Vertragstest ihn als Pfad
  /// erkennt und gegen `docs/openapi.json` prüfen kann.
  static const String pfad = '/api/EmailVersand/signaturen/bild';

  static String fuer(String dateiname) => Uri.parse(
    '${BackendEndpoint.basisUrl}$pfad',
  ).replace(queryParameters: {'dateiname': dateiname}).toString();
}
