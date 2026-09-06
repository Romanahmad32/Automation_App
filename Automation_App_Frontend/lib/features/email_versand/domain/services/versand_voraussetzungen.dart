import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_pruefung.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlagen_fueller.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Prüft, ob die Mail hinausgehen kann, und sagt je Feld, was fehlt (§4.7).
///
/// Beim Testen fiel der Fall auf, in dem eine Prüfung am teuersten fehlt: Der
/// Anwalt tippt die Adresse ein und drückt Senden, ohne sie mit der
/// Eingabetaste übernommen zu haben. Das Feld sieht ausgefüllt aus, der Entwurf
/// hat aber keinen Empfänger — und nichts auf dem Schirm erklärt den
/// Unterschied. Genau dieser Fall steht deshalb an der Empfängerzeile.
///
/// Seit dem 06.09.2026 hält auch ein **offener Platzhalter** die Mail auf: Was
/// noch als `{{...}}` in Betreff oder Text steht, ginge wörtlich beim
/// Versicherer oder beim Gericht an — schlimmer als eine Mail, die gar nicht
/// erst hinausging (§4.7, „Alles oder nichts"). Siehe [offeneIn].
class VersandVoraussetzungen {
  const VersandVoraussetzungen._();

  /// [offenAn] und [offenKopie] sind Texte, die in einer Empfängerzeile stehen,
  /// aber noch nicht übernommen wurden.
  ///
  /// [gesamtBytes] ist die Nachricht mit Anhängen und Signaturbildern,
  /// [maxBytes] die Grenze des Postfachs (null = unbekannt). Die Grenze erst
  /// beim Senden zu nennen, hieße sie nach dem einen unumkehrbaren Klick zu
  /// nennen — der Server der Gegenseite weist die Mail dann ab, und der Anwalt
  /// hat einen Fehler auf Englisch statt einer Zahl vor sich.
  ///
  /// Geprüft wird immer der **Entwurf**, nicht die Vorlage: Was hier steht,
  /// geht hinaus — auch ein von Hand hineingeschriebenes `{{...}}`.
  static VersandPruefung pruefe({
    required EmailEntwurf entwurf,
    String offenAn = '',
    String offenKopie = '',
    int gesamtBytes = 0,
    int? maxBytes,
    Vorgang? vorgang,
  }) {
    return VersandPruefung(
      anFehler:
          _nichtUebernommen(offenAn) ??
          (entwurf.an.isEmpty
              ? 'Ohne Empfänger geht keine Mail hinaus.'
              : null),
      kopieFehler: _nichtUebernommen(offenKopie),
      betreffFehler: entwurf.betreff.trim().isEmpty
          ? 'Ohne Betreff geht keine Mail hinaus.'
          : null,
      platzhalterFehler: _offeneNennen(offeneIn(entwurf, vorgang: vorgang)),
      groesseFehler: maxBytes != null && gesamtBytes > maxBytes
          ? 'Die Nachricht ist mit ${_mb(gesamtBytes)} MB zu groß — die Grenze '
                'liegt bei ${_mb(maxBytes)} MB. Weniger anhängen, die Dateien '
                'verkleinern oder ein Bild aus der Signatur weglassen.'
          : null,
    );
  }

  /// Die Platzhalter, die im **fertigen** Entwurf noch als `{{...}}` stehen
  /// (§4.7, ergänzt am 06.09.2026) — in der Reihenfolge Betreff, dann Text.
  ///
  /// **Was hier noch dasteht, ist offen — ohne zweite Frage.** Ein Platzhalter,
  /// für den es etwas einzusetzen gab, ist beim Füllen ersetzt worden; einer,
  /// der im Dialog gewählt wird (Anrede, Zusatzgruß), hat entweder seinen Wert
  /// oder seine Zeile mitgenommen. Übrig bleibt allein, was wörtlich so
  /// hinausginge — beim Versicherer oder beim Gericht.
  ///
  /// Die Erkennung kommt aus [MailVorlagenFueller.befunde] und nicht aus einem
  /// zweiten Durchlauf über das Muster: So heißen Stelle und Grund hier
  /// genauso wie in der Übersicht im Formular.
  ///
  /// [vorgang] wird **nur für den Grund** mitgegeben, nicht um noch etwas
  /// einzusetzen: Ohne ihn lautete die Erklärung an jedem offenen Namen „kein
  /// Vorgang gewählt", auch wenn einer gewählt ist — und dann zeigte die
  /// Auskunft auf die falsche Lücke. Eingesetzt wird hier ohnehin nichts mehr;
  /// was im fertigen Entwurf noch als `{{...}}` steht, hat den Füller mit den
  /// echten Quellen bereits durchlaufen.
  static List<PlatzhalterBefund> offeneIn(
    EmailEntwurf entwurf, {
    Vorgang? vorgang,
  }) {
    return MailVorlagenFueller(
      anrede: '',
      vorgang: vorgang,
    ).befunde(MailVorlage(betreff: entwurf.betreff, text: entwurf.text));
  }

  /// Der Satz zu den offenen Platzhaltern; null, wenn keiner offen ist.
  ///
  /// Er nennt den Namen **und** die Stelle: „{{MandantTelefon}}" allein
  /// zwingt zum Absuchen des Textes, und der Grund („im Mandantenregister
  /// nicht erfasst") entscheidet, ob nachzupflegen oder zu berichtigen ist.
  static String? _offeneNennen(List<PlatzhalterBefund> offene) {
    if (offene.isEmpty) return null;
    if (offene.length == 1) {
      final einer = offene.single;
      final grund = einer.fehlstelle.isEmpty ? '' : ' — ${einer.fehlstelle}';
      return 'Der Platzhalter ${einer.geschrieben} steht noch offen '
          '(${einer.stelle})$grund. So ginge er wörtlich hinaus.';
    }
    final aufzaehlung = offene
        .map((befund) => '${befund.geschrieben} (${befund.stelle})')
        .join(', ');
    return '${offene.length} Platzhalter stehen noch offen: $aufzaehlung. '
        'So gingen sie wörtlich hinaus.';
  }

  /// Eine eingetippte, aber nicht übernommene Adresse. Sie ginge beim Senden
  /// verloren, ohne dass es jemand merkt — deshalb hält sie den Versand auf.
  static String? _nichtUebernommen(String eingabe) {
    final text = eingabe.trim();
    if (text.isEmpty) return null;
    return 'Die Adresse „$text" ist noch nicht übernommen — mit der '
        'Eingabetaste oder dem Pluszeichen hinzufügen.';
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
