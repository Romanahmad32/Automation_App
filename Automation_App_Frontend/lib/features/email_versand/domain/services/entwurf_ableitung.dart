import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlagen_fueller.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';

/// Woraus Betreff und Text eines Entwurfs entstehen (§4.7): gewählte Vorlage,
/// Empfänger, Zusatzgruß — und ohne Vorlage die Vorbelegung aus dem Vorgang.
///
/// **Betreff und Text sind abgeleitet, nicht eingefügt.** Solange der Anwalt
/// nicht selbst getippt hat, entstehen sie bei jeder Änderung neu: Empfänger
/// dazu, Gruß gewechselt, Vorlage getauscht, Vorgang gewechselt. Nur so folgt
/// die Anrede dem Empfängerkreis — eine einmalige Einfügung bräche genau diese
/// Zusage.
///
/// Eigene Klasse und **nicht** im Cubit, weil daran nichts vom Zustand hängt:
/// Sie nimmt einen Entwurf und gibt einen zurück. Der Cubit entscheidet, ob
/// und wann er das Ergebnis übernimmt ([EmailEntwurfErzeuger] fehlt, solange
/// der Dialog noch lädt), und die Platzhalter-Übersicht im Dialog fragt
/// [fuellerFuer] nach **denselben** Werten, die in den Text gehen — eine
/// zweite Rechnung daneben liefe auseinander.
class EntwurfAbleitung {
  final EmailEntwurfErzeuger erzeuger;

  /// Die gewählte Vorlage; null heisst „keine" und führt zur Vorbelegung.
  final MailVorlage? vorlage;

  /// Der beim Verfassen gewählte Zusatzgruß (§4.7). Ob er im Text landet,
  /// entscheidet die Vorlage — nicht der Empfängerkreis (geändert am
  /// 02.09.2026).
  final String zusatzgruss;

  /// Der beim Verfassen gewählte Anredeanfang (§4.7, §7.1); null heisst:
  /// Rückfall auf die feste Briefanrede des Mandanten.
  final Anredebaustein? anredebaustein;

  /// Ob neutral angeredet wird. **null heisst „wie der Empfängerkreis es
  /// ergibt"** — die Vorgabe; true/false ist die Übersteuerung durch den
  /// Anwalt. Ein eigenes Feld „selbst gesetzt" braucht es dadurch nicht.
  final bool? anredeNeutral;

  /// Die je Mail gewählte Anredeart (§4.7, ergänzt am 02.09.2026); null heisst
  /// „wie am Mandanten hinterlegt". Sie beugt die Anredezeile **und**
  /// `{{Mandant/Mandantin}}` im Vorlagentext.
  ///
  /// Von [anredeNeutral] getrennt, weil es zwei verschiedene Fragen sind: ob
  /// namentlich angeredet wird, hängt am Empfängerkreis; welche Form eines
  /// Wortes gilt, am Mandanten. Eine Mail an die Versicherung beginnt mit
  /// „Sehr geehrte Damen und Herren" und schreibt trotzdem von „unserer
  /// Mandantin".
  final Anrede? geschlecht;

  const EntwurfAbleitung({
    required this.erzeuger,
    this.vorlage,
    this.zusatzgruss = '',
    this.anredebaustein,
    this.anredeNeutral,
    this.geschlecht,
  });

  /// Der Entwurf mit abgeleitetem Text — und auf Wunsch abgeleitetem Betreff.
  ///
  /// [betreffAuch] trennt die **ausdrückliche** Handlung (Vorlage oder Gruß
  /// gewählt — dann darf auch der Betreff neu entstehen) von der beiläufigen
  /// (ein Empfänger kam dazu — dann bleibt der Betreff stehen, wie es hier
  /// schon immer war).
  EmailEntwurf abgeleitet(EmailEntwurf entwurf, {required bool betreffAuch}) {
    final empfaenger = entwurf.alleEmpfaenger;
    final gewaehlt = vorlage;

    if (gewaehlt == null) {
      return entwurf.copyWith(
        text: erzeuger.textFuer(
          empfaenger,
          mitSchreiben: entwurf.anhangPfade.isNotEmpty,
          zusatzgruss: zusatzgruss,
          anredebaustein: anredebaustein,
          anredeNeutral: anredeNeutral,
          geschlecht: geschlecht,
        ),
      );
    }

    final gefuellt = fuellerFuer(empfaenger).fuelleVorlage(gewaehlt);
    return entwurf.copyWith(
      betreff: betreffAuch ? gefuellt.betreff : entwurf.betreff,
      text: gefuellt.text,
    );
  }

  /// Der Betreff aus der **Vorbelegung** — für den Vorgangswechsel ohne
  /// gewählte Vorlage.
  ///
  /// [abgeleitet] rührt ihn dort absichtlich nicht an: Ein hinzugefügter
  /// Empfänger ist keine Ansage, die Betreffzeile neu zu schreiben. Ein
  /// gewechselter Vorgang ist eine — und deshalb steht das hier getrennt.
  String betreffAusVorbelegung(EmailEntwurf entwurf) =>
      erzeuger.betreffFuer(mitSchreiben: entwurf.anhangPfade.isNotEmpty);

  /// Die Anredezeile zum aktuellen Stand — dieselbe, die in den Text geht.
  ///
  /// Öffentlich, weil der Cubit sie **mitschreiben** muss: Im von Hand
  /// bearbeiteten Text tauscht er später genau diese Zeichenfolge gegen die
  /// neue aus (`TextNachtrag`), und dafür braucht er wörtlich, was dort steht.
  String anredeFuer(List<String> empfaenger) => erzeuger.anredeFuer(
    empfaenger,
    baustein: anredebaustein,
    neutral: anredeNeutral,
    geschlecht: geschlecht,
  );

  /// Der Füller zum aktuellen Stand — dieselben Werte, die in den Text gehen.
  MailVorlagenFueller fuellerFuer(List<String> empfaenger) =>
      MailVorlagenFueller(
        anrede: anredeFuer(empfaenger),
        // Ohne Rücksicht auf den Empfängerkreis: Ob der Gruß mitgeht,
        // entscheidet die gewählte Vorlage (§4.7, geändert am 02.09.2026).
        zusatzgruss: zusatzgruss,
        // Aufgelöst und nicht durchgereicht: Der Füller braucht die geltende
        // Anredeart, nicht die Frage, ob eine gewählt wurde.
        geschlecht: erzeuger.geschlechtFuer(geschlecht),
        vorgang: erzeuger.vorgang,
        mandant: erzeuger.mandant,
      );
}
