import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';

/// Wie aus der Betreffzeile einer Mail-Textvorlage der fertige Betreff wird
/// (§4.7).
///
/// **Eigene Klasse, weil ein Betreff keine Zeile ist.** Im Nachrichtentext
/// nimmt ein leerer Platzhalter seine ganze Zeile mit — die Nachbarzeilen
/// tragen den Satz weiter. Der Betreff hat keine Nachbarn: Dieselbe Regel
/// liefert dort eine Zeile, in der die Trennzeichen stehen bleiben und nichts
/// mehr trennen. Aus „Ihre Verkehrsunfallsache {{MandantName}} ./.
/// {{VersichererName}} · Unser Zeichen: {{Referenz}}" wurde ohne Versicherer
/// und ohne Referenz wörtlich „Ihre Verkehrsunfallsache Müller ./. · Unser
/// Zeichen:" — und genau so ging die Mail hinaus (behoben am 03.09.2026).
///
/// Deshalb rechnet der Betreff **je Abschnitt** statt je Zeile: Was zwischen
/// zwei [trenner] steht, ist eine Angabe für sich und geht als Ganzes mit
/// oder gar nicht.
class MailBetreffAufbau {
  const MailBetreffAufbau._();

  /// Das Trennzeichen, an dem die übernommene Kanzlei-Vorlage ihre Angaben
  /// reiht (`MailVorlagenVorgabe` im Dienst).
  static const String trenner = ' · ';

  /// Zieht [vorlage] zusammen; [fuelle] setzt die Werte eines Abschnitts ein
  /// und gibt **null** zurück, wenn er nur Platzhalter trug und keiner davon
  /// einen Wert hatte — dieselbe Zusage wie beim Nachrichtentext.
  ///
  /// Eine Vorlage **ohne** Platzhalter kommt unberührt zurück: Wer zwei
  /// Leerzeichen in seinen Betreff schreibt, hat sie so gemeint. Geglättet
  /// wird nur, was das Einsetzen selbst hinterlässt.
  static String gefuellt(String vorlage, String? Function(String) fuelle) {
    if (!MailPlatzhalter.muster.hasMatch(vorlage)) return vorlage;

    final abschnitte = <String>[];
    for (final abschnitt in vorlage.split(trenner.trim())) {
      final gesetzt = fuelle(abschnitt);
      if (gesetzt == null) continue;
      final sauber = gesetzt.replaceAll(_mehrfachLeer, ' ').trim();
      if (sauber.isEmpty) continue;
      abschnitte.add(sauber);
    }

    return abschnitte
        .join(trenner)
        .replaceFirst(_trennerAmEnde, '')
        .trimRight();
  }

  static final RegExp _mehrfachLeer = RegExp(r'[ \t]{2,}');

  /// Was am Ende steht und nichts mehr trennt: das „./." ohne Gegner, der
  /// Doppelpunkt ohne Aktenzeichen. Nur am **Ende** — mitten im Betreff sagt
  /// „Verkehrsunfallsache ./. HUK" immerhin noch, gegen wen es geht.
  static final RegExp _trennerAmEnde = RegExp(r'(\s|\./\.|[·:,;/–—-])+$');
}
