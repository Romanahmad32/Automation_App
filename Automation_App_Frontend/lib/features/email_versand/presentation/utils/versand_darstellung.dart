import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';

/// Wie ein Versandeintrag in einer Zeile steht (§4.7).
///
/// Eigener Baustein, weil derselbe Satz an drei Stellen gebraucht wird — in
/// der Vorgangsliste, im Abschlussdialog und im Protokollfenster — und weil
/// die **Unterscheidung** darin die wichtigste Angabe ist: „versendet" darf
/// nur stehen, wo die App die Einlieferung wirklich gesehen hat.
abstract final class VersandDarstellung {
  /// „28.08.2026 um 14:12" — dieselbe Schreibweise wie im Postfach.
  static String zeitpunkt(DateTime wann) =>
      '${deutschesDatum(wann)} um ${deutscheUhrzeit(wann)}';

  /// Was mit der Mail geschah — im Perfekt, wie der Anwalt es erzählen würde.
  static String tat(VersandWeg weg) => switch (weg) {
    VersandWeg.direktversand => 'Versendet',
    VersandWeg.outlookEntwurf => 'An Outlook übergeben',
    VersandWeg.entwurfsdatei => 'Als Entwurfsdatei abgelegt',
  };

  /// Die Zeile für die Übersicht: Was, wann, an wen.
  static String kurz(VersandEintrag eintrag) {
    final wer = eintrag.alleEmpfaenger.join(', ');
    final satz = '${tat(eintrag.weg)} am ${zeitpunkt(eintrag.gesendetAm)}';
    return wer.isEmpty ? satz : '$satz an $wer';
  }

  /// Wo die Mail selbst nachzusehen ist — beim Direktversand der Ordner
  /// „Gesendet" des Postfachs und damit Outlook am selben Konto. Schlug das
  /// Nachtragen fehl, muss das dastehen: Sonst sucht der Anwalt dort umsonst.
  static String? ablage(VersandEintrag eintrag) {
    if (!eintrag.weg.istNachweis) {
      return 'Ob im Mailprogramm tatsächlich gesendet wurde, weiß die App '
          'nicht — sie hat die Nachricht nur dorthin übergeben.';
    }
    return eintrag.imGesendetOrdner
        ? 'Die Mail liegt im Ordner „Gesendet" des Postfachs — in Outlook am '
              'selben Konto ist sie dort zu finden.'
        : 'Die Kopie im Ordner „Gesendet" ließ sich nicht ablegen; im '
              'Mailprogramm ist die Mail deshalb möglicherweise nicht zu sehen.';
  }
}
