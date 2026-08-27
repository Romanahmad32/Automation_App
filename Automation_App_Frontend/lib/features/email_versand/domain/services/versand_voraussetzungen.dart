import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';

/// Was noch fehlt, damit die Mail hinausgehen kann (§4.7).
///
/// Ein abgeblendeter „Senden"-Knopf ist eine Behauptung ohne Begründung. Beim
/// Testen fiel genau der Fall auf, in dem er am teuersten ist: Der Anwalt tippt
/// die Adresse ein und drückt Senden, ohne sie mit der Eingabetaste übernommen
/// zu haben. Das Feld sieht ausgefüllt aus, der Entwurf hat aber keinen
/// Empfänger — und nichts auf dem Schirm erklärt den Unterschied.
class VersandVoraussetzungen {
  const VersandVoraussetzungen._();

  /// Die offenen Punkte im Klartext, leer wenn gesendet werden kann.
  ///
  /// [offeneEingaben] sind Texte, die in einer Empfängerzeile stehen, aber noch
  /// nicht übernommen wurden. Sie stehen bewusst **zuerst**: Sie sind der
  /// einzige Punkt, den der Anwalt nicht sieht, indem er auf das Formular
  /// schaut.
  /// [gesamtBytes] ist die Nachricht mit Anhängen und Signaturbildern,
  /// [maxBytes] die Grenze des Postfachs (null = unbekannt). Die Grenze erst
  /// beim Senden zu nennen, hieße sie nach dem einen unumkehrbaren Klick zu
  /// nennen — der Server der Gegenseite weist die Mail dann ab, und der Anwalt
  /// hat einen Fehler auf Englisch statt einer Zahl vor sich.
  static List<String> fehlend({
    required EmailEntwurf entwurf,
    List<String> offeneEingaben = const [],
    int gesamtBytes = 0,
    int? maxBytes,
  }) {
    final offen = offeneEingaben
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty);

    return [
      for (final text in offen)
        'Die Adresse „$text" ist noch nicht übernommen — mit der Eingabetaste '
            'oder dem Pluszeichen hinzufügen.',
      if (entwurf.an.isEmpty) 'ein Empfänger im Feld „An"',
      if (entwurf.betreff.trim().isEmpty) 'ein Betreff',
      if (maxBytes != null && gesamtBytes > maxBytes)
        'Die Nachricht ist mit ${_mb(gesamtBytes)} MB zu groß — die Grenze '
            'liegt bei ${_mb(maxBytes)} MB. Weniger anhängen, die Dateien '
            'verkleinern oder ein Bild aus der Signatur weglassen.',
    ];
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
