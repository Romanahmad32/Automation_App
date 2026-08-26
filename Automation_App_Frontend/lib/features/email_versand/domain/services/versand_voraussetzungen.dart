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
  static List<String> fehlend({
    required EmailEntwurf entwurf,
    List<String> offeneEingaben = const [],
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
    ];
  }
}
