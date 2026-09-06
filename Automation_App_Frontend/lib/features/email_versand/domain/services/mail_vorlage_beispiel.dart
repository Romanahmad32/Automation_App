import 'package:automation_app/features/email_versand/domain/services/mail_vorlagen_fueller.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

/// Der **Beispielvorgang**, an dem der Vorlageneditor zeigt, was aus einer
/// Vorlage wird (§4.7, ergänzt am 06.09.2026).
///
/// **Der Mangel, den das behebt:** Man schrieb blind. Wie `{{Anrede}}` oder
/// `{{VersichererAnschrift}}` am Ende aussehen, sah der Anwalt erst Wochen
/// später im Versanddialog — an einer Vorlage, die längst als fertig galt.
///
/// Erfundene Daten und ausdrücklich als solche kenntlich („Muster",
/// „example.de"): Ein echter Vorgang stünde hier in den Einstellungen, weit weg
/// von seiner Akte, und die Vorschau sähe aus wie ein Entwurf an einen echten
/// Mandanten. Gefüllt ist der Beispielvorgang trotzdem **vollständig** — eine
/// Vorschau mit Lücken zeigte offene Platzhalter, die in Wahrheit keine sind.
abstract final class MailVorlageBeispiel {
  /// Die Anredezeile, die der Versand aus dem Anredebestand baut. Sie kommt im
  /// Dialog aus dem `EmailEntwurfErzeuger`; für die Vorschau reicht die Form,
  /// die die App ab Werk erzeugt.
  static const String anrede = 'Sehr geehrte Frau Muster';

  static const String zusatzgruss = 'Mit den besten Grüßen vorab';

  /// Die Adresse, die in der Vorschau unter „An" steht.
  static const String empfaenger = 'a.muster@example.de';

  /// Der Absender, der in der Vorschau unter „Von" steht.
  static const String absender = 'kanzlei@example.de';

  static final Mandant mandant = Mandant(
    id: 1,
    anrede: Anrede.frau,
    vorname: 'Anna',
    nachname: 'Muster',
    strasseHausnummer: 'Musterweg 3',
    postleitzahl: '61348',
    ort: 'Bad Homburg',
    emailAdresse: empfaenger,
    telefonnummer: '06172 1234567',
    persoenlicheGrussformel: zusatzgruss,
    erstelltAm: DateTime(2026, 1, 1),
  );

  static final Vorgang vorgang = Vorgang(
    referenz: '12/26 C01_HG-E 1427',
    angefragtAm: DateTime(2026, 3, 2),
    laufendeNummer: 12,
    jahr: '26',
    abteilung: 'C01',
    kennzeichen: 'HG-E 1427',
    mandantId: 1,
    mandantName: 'Anna Muster',
    gegner: 'Muster Versicherung AG',
    unfallDatum: '28.02.2026',
    geschaedigtenKennzeichen: 'HG-AM 42',
    unfallort: 'Bad Homburg, Louisenstraße',
    unfalluhrzeit: '14:20',
    polizeiVorgangsnummer: 'ST/0123456/2026',
    antwort: const ZentralrufReplyData(
      versichererName: 'Muster Versicherung AG',
      versichererStrasse: 'Versicherungsplatz 1',
      versichererPlz: '50667',
      versichererOrt: 'Köln',
      versichererTelefon: '0221 1000000',
      versichererEmail: 'schaden@example.de',
      versicherungsscheinNr: 'VS-2026-0815',
      kennzeichen: 'K-MV 900',
      unfallDatum: '28.02.2026',
    ),
  );

  /// Der Füller, mit dem der Editor die Vorlage vorführt — dieselbe Klasse,
  /// die auch beim Versand einsetzt. Eine zweite Rechnung daneben liefe
  /// auseinander, und genau das soll die Vorschau ausschließen.
  static MailVorlagenFueller fueller() => MailVorlagenFueller(
    anrede: anrede,
    zusatzgruss: zusatzgruss,
    geschlecht: Anrede.frau,
    vorgang: vorgang,
    mandant: mandant,
  );

  /// Die Fußzeile unter der Vorschau. Sie sagt, dass hier nichts Echtes steht —
  /// sonst liest sich die Vorschau wie ein fertiger Entwurf.
  static const String hinweis =
      'Beispieldaten: ein erfundener Vorgang „12/26 C01_HG-E 1427". Beim '
      'Verfassen stehen hier die Angaben des gewählten Vorgangs, und die '
      'Signatur der Kanzlei hängt der Versand an.';
}
