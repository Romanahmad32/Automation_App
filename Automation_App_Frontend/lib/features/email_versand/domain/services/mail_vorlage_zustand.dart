import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/vorlagen_pruefung.dart';

/// Ob eine Mail-Textvorlage fertig ist — das Abzeichen je Zeile in der
/// Übersicht (§4.7, ergänzt am 06.09.2026).
///
/// **Der Mangel, den das behebt:** Die Liste zeigte Name und Betreff, also
/// zweimal das, was der Anwalt selbst hingeschrieben hat. Ob eine Vorlage
/// überhaupt einen Text hat und ob ihre Platzhalter je etwas liefern werden,
/// stand nirgends — das erfuhr er erst beim Verfassen, unter Zeitdruck.
///
/// **„Offen" heisst hier: löst auf kein Feld auf.** Ob eine Angabe am *Vorgang*
/// fehlt, kann die Übersicht nicht wissen — in den Einstellungen gibt es
/// keinen. Was sie sehr wohl weiss: ob ein Name überhaupt einer Datenquelle
/// entspricht. Gerechnet wird das in [VorlagenPruefung], derselben Stelle, die
/// den Editor speist; zwei Rechnungen liefen auseinander.
class MailVorlageZustand {
  /// Was am Abzeichen steht.
  final String text;

  /// Ob die Vorlage einsatzbereit ist — dann ist das Abzeichen ruhig, sonst
  /// trägt es den Hinweiston der App (`tertiary`, kein Alarmrot: eine Vorlage
  /// im Werden ist kein Fehler).
  final bool inOrdnung;

  const MailVorlageZustand({required this.text, required this.inOrdnung});

  /// Der Zustand einer Vorlage: **Ohne Text** schlägt alles andere — eine
  /// Vorlage ohne Anschreiben ist nicht „vollständig", auch wenn sie keinen
  /// einzigen fraglichen Platzhalter hat.
  static MailVorlageZustand fuer(MailVorlage vorlage) {
    if (vorlage.text.trim().isEmpty) {
      return const MailVorlageZustand(text: 'Ohne Text', inOrdnung: false);
    }

    final offen = VorlagenPruefung.maengel(vorlage).length;
    if (offen == 0) {
      return const MailVorlageZustand(text: 'Vollständig', inOrdnung: true);
    }
    return MailVorlageZustand(
      text: offen == 1 ? 'Ein Platzhalter offen' : '$offen Platzhalter offen',
      inOrdnung: false,
    );
  }
}
