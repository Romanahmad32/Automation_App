import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_eintrag.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_gruppe.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_katalog.dart';

/// Die Platzhalter, die in einer Mail-Textvorlage stehen dürfen (§4.7) — in
/// derselben Schreibweise wie in den Word-Vorlagen: `{{Name}}`.
///
/// Zwei Herkünfte, und die Reihenfolge entscheidet: [anrede] und [zusatzgruss]
/// beantwortet der Versand selbst, weil beide beim Verfassen dieser einen Mail
/// entstehen und nicht am Vorgang stehen. Alles Übrige löst die vorhandene
/// Ersetzung der Formularvorlagen auf (`FeldDatenquelleErkennung` →
/// `VorgangPrefillMatcher`) — dieselben Namen, dieselbe Schreibweise, damit
/// niemand zwei Kataloge im Kopf behalten muss.
class MailPlatzhalter {
  const MailPlatzhalter._();

  /// Die Anrede der Mail. Sie steht in der Vorlage und nicht davor, damit jede
  /// Vorlage selbst bestimmt, ob und wie angeredet wird.
  static const String anrede = 'Anrede';

  /// Der beim Verfassen gewählte Zusatzgruß (§4.7). Steht er in einer Vorlage,
  /// wird er eingesetzt — **ohne Rücksicht darauf, wer im Feld „An" steht**:
  /// Die Vorlage ist die Entscheidung. Wer eine Vorlage mit diesem Platzhalter
  /// wählt, will den Gruß; wer ihn nicht will, nimmt eine Vorlage ohne ihn.
  ///
  /// Geschrieben wie gesprochen (`{{Zusatzgruß}}`); über die Normalisierung
  /// verglichen, damit `{{Zusatzgruss}}` mit ss dasselbe meint.
  static const String zusatzgruss = 'Zusatzgruß';

  /// Findet `{{Name}}` samt Namen. Bewusst dieselbe Form wie im Backend
  /// (`WordAutomationService`); wer sie hier ändert, hat zwei Schreibweisen.
  static final RegExp muster = RegExp(r'\{\{\s*([^{}]+?)\s*\}\}');

  /// **Alle** Platzhalter, die eine Mail-Textvorlage füllen kann — zur Auswahl
  /// in der Verwaltung (§4.7, ergänzt am 02.09.2026).
  ///
  /// Hier stand bis dahin eine handgeschriebene Liste von sechs „häufigen"
  /// Namen, mit dem Eingeständnis im Kommentar, dass eine vollständige
  /// Aufzählung „stillschweigend veraltet". Die Folge war, dass der Anwalt die
  /// übrigen sechsundzwanzig Namen **raten** musste — und die Auflösung ist
  /// eine Heuristik: Wer `{{Adresse}}` tippt, bekommt nichts und erfährt nicht,
  /// warum.
  ///
  /// Jetzt kommt die Liste aus `PlatzhalterKatalog`, also aus derselben
  /// Aufzählung, die auch die Ersetzung benutzt. Davor die zwei Angaben, die
  /// **diese eine Mail** mitbringt und die an keinem Vorgang stehen.
  static List<PlatzhalterEintrag> katalog() => [
    const PlatzhalterEintrag(
      platzhalter: anrede,
      bezeichnung: 'Anrede — folgt dem Empfängerkreis',
      gruppe: PlatzhalterGruppe.verfassen,
    ),
    const PlatzhalterEintrag(
      platzhalter: zusatzgruss,
      bezeichnung: 'Zusatzgruß — beim Verfassen gewählt',
      gruppe: PlatzhalterGruppe.verfassen,
    ),
    // Zwei Beugungen als Muster, keine Aufzählung: Es gibt beliebig viele,
    // denn die Formen stehen in der Vorlage und nicht in einer Liste. Ein
    // Hauptwort und ein Fürwort zeigen die Schreibweise an den zwei Stellen,
    // an denen das Deutsche hier beugt (§4.7, ergänzt am 02.09.2026).
    const PlatzhalterEintrag(
      platzhalter: 'Mandant/Mandantin',
      bezeichnung:
          'Beugung — die Form folgt der Anredeart; ohne Angabe stehen beide '
          'mit Schrägstrich. Dritte Form möglich: {{Mandant/Mandantin/'
          'Mandantschaft}}',
      gruppe: PlatzhalterGruppe.verfassen,
    ),
    const PlatzhalterEintrag(
      platzhalter: 'er/sie',
      bezeichnung:
          'Beugung — dasselbe für Fürwörter und Endungen, z. B. '
          '{{sein/ihr}} oder {{Geschädigter/Geschädigte}}',
      gruppe: PlatzhalterGruppe.verfassen,
    ),
    ...PlatzhalterKatalog.vorgangsfelder(),
  ];

  /// Ob [name] einer der Platzhalter ist, die **der Versand selbst**
  /// beantwortet ([anrede], [zusatzgruss]) — sie stehen in keinem
  /// Datenquellen-Katalog und dürfen deshalb nirgends als „unbekannter Name"
  /// gelten. Die eine Stelle, die das entscheidet.
  static bool istEigen(String name) {
    final gesucht = FeldDatenquelleErkennung.normalisiere(name);
    return gesucht == FeldDatenquelleErkennung.normalisiere(anrede) ||
        gesucht == FeldDatenquelleErkennung.normalisiere(zusatzgruss);
  }

  /// Die Platzhalternamen in [text], in der Reihenfolge ihres ersten
  /// Auftretens und jeder nur einmal — verglichen über die Normalisierung, wie
  /// beim Einsetzen.
  ///
  /// Die gemeinsame Grundlage von Vorlageneditor (Vorschau und Prüfung) und
  /// Versanddialog. Ohne sie hätte jede der Stellen ihren eigenen Durchlauf
  /// über [muster] — und damit ihre eigene Antwort auf die Frage, was in
  /// dieser Vorlage überhaupt steht.
  static List<String> namenIn(String text) {
    final gesehen = <String>{};
    final gefunden = <String>[];
    for (final treffer in muster.allMatches(text)) {
      final name = treffer.group(1)!.trim();
      if (gesehen.add(FeldDatenquelleErkennung.normalisiere(name))) {
        gefunden.add(name);
      }
    }
    return gefunden;
  }

  /// Ob [name] als `{{Name}}` in [text] steht — über die Normalisierung
  /// verglichen, wie beim Einsetzen.
  ///
  /// Der Versanddialog fragt damit, ob die **gewählte Vorlage** die Anrede und
  /// den Zusatzgruß überhaupt aufnehmen kann (`anredeMoeglich`,
  /// `grussMoeglich`). Kann sie es nicht, sperrt er die Reihe sichtbar und
  /// sagt warum: Chips, die nachweislich nichts bewirken, wären schlimmer als
  /// eine gesperrte Reihe mit Begründung.
  ///
  /// Der Block stand bis zum 02.09.2026 über [istEigen] — beim Herausziehen
  /// verrutscht, und damit war die Erklärung genau dort weg, wo die zwei
  /// Sperren des Dialogs zusammenlaufen.
  static bool stehtIn(String text, String name) {
    final gesucht = FeldDatenquelleErkennung.normalisiere(name);
    return muster
        .allMatches(text)
        .any(
          (treffer) =>
              FeldDatenquelleErkennung.normalisiere(treffer.group(1)!) ==
              gesucht,
        );
  }

  /// `{{Referenz}}` und nicht `{{Aktenzeichen}}`: Der gemeinsame Katalog
  /// (`FeldDatenquelleErkennung`) löst **beide** Namen auf die vollständige
  /// Referenz auf — `84/26 C03_GG-XY 123`, mit Kennzeichen. Wer hier
  /// „Aktenzeichen" anböte, verspräche die kurze Form und lieferte die lange.
  static const String referenz = 'Referenz';
}
