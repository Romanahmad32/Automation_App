import 'package:automation_app/core/backend/backend_endpoint.dart';

/// Woher die Vorschau die Bilder der Signatur bekommt (§4.7).
///
/// Die Bilder sind das, was der Anwalt in der Vorschau sucht, wenn er wissen
/// will, ob das Logo mitgeht. Der Dienst liefert sie einzeln aus, die Vorschau
/// lädt sie über diese Adresse.
///
/// **Die Adresse trägt mehr als den Dateinamen**, und beides behebt denselben
/// Fehler (04.09.2026): Outlook nennt das erste Bild jeder Signatur
/// `image001.png`, der Name unterscheidet zwei Logos also nicht.
///
/// * [marke] ist der Inhalt in Kurzform. Flutter hebt geladene Bilder je
///   Adresse auf (`ImageCache`); ohne sie blieb nach einem Signaturwechsel das
///   alte Logo stehen, ohne dass die App überhaupt noch nachfragte — bis zu
///   ihrem Neustart, in jedem Reiter.
/// * [ausOutlook] ist der Name einer in Outlook eingerichteten Signatur. Damit
///   liest der Dienst in deren Beiordner statt in seiner Ablage — für eine
///   gelesene, noch nicht gespeicherte Signatur, deren Bilder dort noch gar
///   nicht liegen. Ohne diesen Weg lieferte die Ablage unter demselben Namen
///   das Logo der **vorigen** Signatur aus, und die Vorschau zeigte es als das
///   neue.
abstract final class SignaturBildQuelle {
  /// Getrennt vom Rest der Adresse, damit der Vertragstest ihn als Pfad
  /// erkennt und gegen `docs/openapi.json` prüfen kann.
  static const String pfad = '/api/EmailVersand/signaturen/bild';

  static String fuer(
    String dateiname, {
    String marke = '',
    String ausOutlook = '',
  }) => Uri.parse('${BackendEndpoint.basisUrl}$pfad')
      .replace(
        queryParameters: {
          'dateiname': dateiname,
          if (marke.isNotEmpty) 'marke': marke,
          if (ausOutlook.isNotEmpty) 'ausOutlook': ausOutlook,
        },
      )
      .toString();
}
