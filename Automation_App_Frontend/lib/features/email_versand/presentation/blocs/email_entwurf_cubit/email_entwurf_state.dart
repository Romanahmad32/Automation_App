import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_empfaenger_vorschlag.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_pruefung.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:automation_app/features/email_versand/domain/services/versand_voraussetzungen.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:equatable/equatable.dart';

/// Wo der Entwurf gerade steht.
enum EmailVersandPhase {
  /// Der Anwalt verfasst; senden ist möglich, sobald der Entwurf vollständig ist.
  verfassen,

  /// Läuft gerade hinaus — währenddessen ist nichts änderbar.
  sendet,

  /// Wird gerade ans Mailprogramm übergeben. Ebenfalls nichts änderbar:
  /// Ein kalt startendes Outlook braucht dafür spürbar Zeit.
  uebergibt,

  /// Versendet. Ab hier zählt nur noch der Abschluss des Vorgangs (§4.8).
  gesendet,
}

/// Zustand des Mail-Entwurfs zu einem Vorgang (§4.7).
class EmailEntwurfState extends Equatable {
  final EmailEntwurf entwurf;
  final List<EmailEmpfaengerVorschlag> vorschlaege;

  /// Anhänge, die aus der offenen Outlook-Nachricht geholt wurden. Sie werden
  /// **angeboten**, nicht angehängt — was mitgeht, entscheidet der Anwalt.
  final List<String> ausOutlook;

  /// Der letzte Griff nach Outlook: aus welcher Nachricht die Vorschläge
  /// stammen. Bleibt stehen, solange sie in der Reihe liegen — sonst lägen
  /// Dateien da, ohne dass etwas sagt, woher sie kommen.
  final OutlookAnhaenge? outlookQuelle;

  /// True, solange Outlook nach seinen Anhängen gefragt wird.
  final bool holtAusOutlook;

  /// Was die Anhänge zusammen wiegen. Einmal beim Ändern gemessen und nicht
  /// bei jedem Neubau: Das Formular baut bei jedem Anschlag neu, und ein
  /// Plattenzugriff je Anhang und Tastendruck wäre teuer für eine Zahl, die
  /// sich beim Tippen nicht ändert.
  final int anhangBytes;

  /// Ob überhaupt gesendet werden kann; null, solange nicht abgefragt.
  final EmailVersandBereitschaft? bereitschaft;

  /// Welches Outlook auf diesem Rechner steht. Bis der Dienst geantwortet hat
  /// gilt `unbekannt` — dann wird nichts behauptet und nichts abgeschaltet.
  final OutlookStand outlookStand;

  final EmailVersandPhase phase;

  /// Meldung des letzten fehlgeschlagenen Versuchs im Klartext. Bleibt stehen,
  /// bis der Anwalt etwas ändert — sie sagt ihm, was zu tun ist.
  final String? fehler;

  final EmailVersandErgebnis? ergebnis;

  /// Der zuletzt ans Mailprogramm übergebene Entwurf. Bleibt stehen, damit
  /// der Dialog sagen kann, dass die Mail dort liegt — und der Anwalt sie
  /// nicht versehentlich ein zweites Mal übergibt oder gar direkt sendet.
  final EmailEntwurfErgebnis? entwurfErgebnis;

  /// Was in der Zeile „An" steht, aber noch nicht übernommen wurde. Der
  /// Zustand führt es mit, weil die Prüfung beim Senden es sehen muss: Das Feld
  /// allein weiß davon, und „Senden" steht woanders im Dialog.
  final String offenAn;

  final String offenKopie;

  /// True, sobald „Senden" oder „In Outlook öffnen" einmal gedrückt wurde. Erst
  /// danach markiert das Formular, was fehlt — vorher wäre jedes leere Feld ein
  /// Vorwurf an einen Entwurf, der gerade erst aufgegangen ist.
  final bool versandVersucht;

  /// True, sobald der Anwalt den Text selbst angefasst hat. Danach schreibt die
  /// automatische Anrede ihn nicht mehr um — sonst verlöre er beim Hinzufügen
  /// eines Empfängers, was er schon getippt hat.
  final bool textSelbstGeschrieben;

  /// Die gewählte Mail-Textvorlage (§4.7); null heisst „keine" und führt zur
  /// Vorbelegung aus den Vorgangsdaten zurück. Steht hier ganz und nicht nur
  /// als Nummer, weil Betreff und Text bei jeder Änderung an Empfängern oder
  /// Zusatzgruß neu daraus abgeleitet werden — und weil die
  /// Platzhalter-Übersicht sie braucht.
  final MailVorlage? gewaehlteVorlage;

  /// Der beim Verfassen gewählte persönliche Zusatzgruß (§4.7), vorbelegt aus
  /// dem Mandanten (§5.1). Leer heisst: keiner.
  final String zusatzgruss;

  /// Ob neben dem Mandanten noch jemand im Feld „An" oder „Kopie" steht. Nur
  /// ein **Hinweis** an der Gruß-Auswahl, keine Sperre (§4.7, geändert am
  /// 02.09.2026): Ob der persönliche Gruß trotzdem mitgeht, entscheidet der
  /// Anwalt über die Vorlage. Steht im Zustand, weil nur der
  /// `EmailEntwurfErzeuger` die Mandantenadresse kennt.
  final bool mitleserImAn;

  /// Der Vorgang, aus dem vorbelegt wird — im Dialog wählbar (§4.7). Null
  /// heisst: keiner, dann entsteht ein leeres Anschreiben und es wird nichts
  /// protokolliert.
  final Vorgang? vorgang;

  /// True, solange der gewechselte Vorgang eingelesen wird. Der Mandant dazu
  /// kommt aus dem Register, und das ist ein Zugriff — bis er da ist, bleibt
  /// das Formular stehen, statt auf halbem Stand zu antworten.
  final bool wechseltVorgang;

  /// Der beim Verfassen gewählte Anredeanfang (§4.7, §7.1), vorbelegt mit dem
  /// ersten des Bestands. Null heisst: Rückfall auf die feste Briefanrede —
  /// der Bestand kann leer sein, und dann darf keine Mail ohne Anrede
  /// hinausgehen.
  final Anredebaustein? anredebaustein;

  /// Ob neutral angeredet wird („Sehr geehrte Damen und Herren").
  ///
  /// **null ist die Vorgabe und heisst „wie der Empfängerkreis es ergibt"**:
  /// namentlich, solange nur der Mandant im Feld „An" steht. true/false ist
  /// die Übersteuerung durch den Anwalt — und weil null davon unterscheidbar
  /// ist, braucht es kein zweites Feld „hat er selbst gesetzt".
  final bool? anredeNeutral;

  /// Ob eine namentliche Anrede überhaupt möglich wäre: nur der Mandant im Feld
  /// „An", und Geschlecht sowie Nachname sind hinterlegt. Steht im Zustand wie
  /// [mitleserImAn], weil nur der `EmailEntwurfErzeuger` den Mandanten kennt.
  final bool anredePersoenlichMoeglich;

  /// Die je Mail **gewählte** Anredeart (§4.7, ergänzt am 02.09.2026); null
  /// heisst „wie am Mandanten hinterlegt" ([mandantAnrede]).
  ///
  /// Sie beugt die Anredezeile und `{{Mandant/Mandantin}}` im Vorlagentext.
  /// Getrennt von [anredeNeutral], weil es zwei Fragen sind: ob namentlich
  /// angeredet wird, hängt am Empfängerkreis; welche Form eines Wortes gilt,
  /// am Mandanten. Eine Mail an die Versicherung beginnt mit „Sehr geehrte
  /// Damen und Herren" und schreibt trotzdem von „unserer Mandantin".
  final Anrede? anredeGeschlecht;

  /// Was das Mandantenregister zur Anredeart sagt (§5.1) — die Vorbelegung.
  /// Steht im Zustand wie [anredePersoenlichMoeglich], weil nur der
  /// `EmailEntwurfErzeuger` den Mandanten kennt; die Chipreihe braucht sie,
  /// um zu zeigen, welche Form ohne Klick gilt.
  final Anrede mandantAnrede;

  /// Ob zum Vorgang ueberhaupt ein Mandant im Register steht. Ohne ihn gibt
  /// es nichts nachzutragen — der Knopf „Im Register hinterlegen" darf dann
  /// nicht erscheinen, denn er haette kein Ziel.
  final bool mandantBekannt;

  /// Die Anredezeile, die **zuletzt in den Text geschrieben** wurde — und
  /// die dort noch woertlich so steht.
  ///
  /// Nur fuer den von Hand bearbeiteten Text: Ab da leitet die App nicht
  /// mehr ab, kann aber genau diese Stelle noch austauschen
  /// (`TextNachtrag`). Ohne die Merker waere jeder Klick auf einen
  /// Anrede-Chip ein stiller Leerlauf — genau das war der Mangel.
  final String anredeImText;

  /// Der Zusatzgruss, der zuletzt in den Text geschrieben wurde. Leer
  /// heisst: es stand keiner drin, und dann gibt es nichts zu tauschen.
  final String zusatzgrussImText;

  const EmailEntwurfState({
    this.entwurf = const EmailEntwurf(),
    this.vorschlaege = const [],
    this.ausOutlook = const [],
    this.outlookQuelle,
    this.holtAusOutlook = false,
    this.anhangBytes = 0,
    this.bereitschaft,
    this.outlookStand = OutlookStand.unbekannt,
    this.phase = EmailVersandPhase.verfassen,
    this.fehler,
    this.ergebnis,
    this.entwurfErgebnis,
    this.offenAn = '',
    this.offenKopie = '',
    this.versandVersucht = false,
    this.textSelbstGeschrieben = false,
    this.gewaehlteVorlage,
    this.zusatzgruss = '',
    this.mitleserImAn = false,
    this.vorgang,
    this.wechseltVorgang = false,
    this.anredebaustein,
    this.anredeNeutral,
    this.anredePersoenlichMoeglich = false,
    this.anredeGeschlecht,
    this.mandantAnrede = Anrede.keine,
    this.mandantBekannt = false,
    this.anredeImText = '',
    this.zusatzgrussImText = '',
  });

  /// Was der Mail noch fehlt, je Feld (§4.7).
  VersandPruefung get pruefung => VersandVoraussetzungen.pruefe(
    entwurf: entwurf,
    offenAn: offenAn,
    offenKopie: offenKopie,
    gesamtBytes: gesamtBytes,
    maxBytes: bereitschaft?.maxBytes,
  );

  /// Was das Formular anzeigen darf: nichts, bis der erste Versuch gelaufen
  /// ist.
  VersandPruefung get markiert =>
      versandVersucht ? pruefung : VersandPruefung.ohneMangel;

  bool get sendetGerade => phase == EmailVersandPhase.sendet;

  bool get uebergibtGerade => phase == EmailVersandPhase.uebergibt;

  /// Solange die App arbeitet, bleibt das Formular stehen — egal auf welchem
  /// der beiden Wege, und auch beim Vorgangswechsel: Der belegt Empfänger,
  /// Betreff und Text neu, und ein Anschlag mitten hinein ginge verloren.
  bool get beschaeftigt => sendetGerade || uebergibtGerade || wechseltVorgang;

  /// Ob die Anrede neutral ausfällt — die Rechnung hinter dem Umschalter:
  /// Der Anwalt entscheidet, wenn er entschieden hat; sonst der Empfängerkreis.
  bool get anredeGehtNeutral => anredeNeutral ?? !anredePersoenlichMoeglich;

  /// Die Anredeart, die **jetzt** gilt: die gewaehlte schlaegt die am
  /// Mandanten hinterlegte. Dieselbe Rechnung wie in
  /// `EmailEntwurfErzeuger.geschlechtFuer` — hier nur fuer die Chipreihe,
  /// damit sie zeigt, was ohne Klick gilt.
  Anrede get geschlecht => anredeGeschlecht ?? mandantAnrede;

  /// Ob die gewaehlte Anredeart einer **hinterlegten** widerspricht. Nur
  /// dann ist „gilt nur fuer diese Mail" die richtige Auskunft: Steht am
  /// Register nichts, wird nichts uebergangen — dann ist es eine Luecke,
  /// und dafuer gibt es [anredeartNachtragbar].
  bool get anredeartWeichtAb =>
      mandantAnrede != Anrede.keine &&
      anredeGeschlecht != null &&
      anredeGeschlecht != mandantAnrede;

  /// Ob sich die gewaehlte Anredeart im Register **nachtragen** laesst: Dort
  /// steht keine, hier ist eine gewaehlt, und ein Mandant existiert.
  ///
  /// Bewusst nur die Luecke und nie die Korrektur (§1.3): Eine hinterlegte
  /// Anredeart aus dem Versanddialog zu ueberschreiben waere eine Aenderung
  /// an Stammdaten im Vorbeigehen. Die gehoert ins Register.
  bool get anredeartNachtragbar =>
      mandantBekannt &&
      mandantAnrede == Anrede.keine &&
      anredeGeschlecht != null &&
      anredeGeschlecht != Anrede.keine;

  /// Ob der gewählte Zusatzgruß überhaupt eingesetzt werden kann: Die Vorlage
  /// muss den Platzhalter `{{Zusatzgruß}}` tragen (§4.7, geändert am
  /// 02.09.2026). Ohne Vorlage gilt die Vorbelegung, und die hat immer eine
  /// Stelle dafür.
  ///
  /// **Abgeleitet und nicht gespeichert:** Die Auskunft hängt allein an der
  /// gewählten Vorlage. Als Feld liefe sie hinter jeder Vorlagenwahl her, und
  /// gerade das ist der Fall, in dem sie sich ändert.
  bool get grussMoeglich {
    final vorlage = gewaehlteVorlage;
    if (vorlage == null) return true;
    return MailPlatzhalter.stehtIn(vorlage.text, MailPlatzhalter.zusatzgruss) ||
        MailPlatzhalter.stehtIn(vorlage.betreff, MailPlatzhalter.zusatzgruss);
  }

  /// Ob die gewählte Vorlage überhaupt eine Stelle für die **Anrede** hat: Sie
  /// muss den Platzhalter `{{Anrede}}` tragen (§4.7, ergänzt am 02.09.2026).
  /// Ohne Vorlage gilt die Vorbelegung, und die hat immer eine.
  ///
  /// Fehlt die Stelle, geht die Mail **ohne Anredezeile** hinaus — und dann
  /// sind beide Reihen darüber wirkungslos, ohne es zu sagen. Genau wie
  /// [grussMoeglich], nur für die Zeile darüber; abgeleitet und nicht
  /// gespeichert, weil die Auskunft allein an der gewählten Vorlage hängt.
  bool get anredeMoeglich {
    final vorlage = gewaehlteVorlage;
    if (vorlage == null) return true;
    return MailPlatzhalter.stehtIn(vorlage.text, MailPlatzhalter.anrede) ||
        MailPlatzhalter.stehtIn(vorlage.betreff, MailPlatzhalter.anrede);
  }

  /// Was die mitgehenden Signaturbilder wiegen. Was der Anwalt für diese
  /// Mail weggelassen hat, zählt nicht mit — genau deshalb lässt er es weg.
  int get signaturBytes => (bereitschaft?.signaturBilder ?? [])
      .where((bild) => entwurf.signaturBildGehtMit(bild.dateiname))
      .fold(0, (summe, bild) => summe + bild.bytes);

  /// Die Nachricht, wie der Postausgangsserver sie zählt.
  int get gesamtBytes => anhangBytes + signaturBytes;

  /// True, wenn das Postfach die Nachricht abweisen würde.
  bool get ueberGrenze {
    final grenze = bereitschaft?.maxBytes;
    return grenze != null && gesamtBytes > grenze;
  }

  /// Ob der Knopf anfassbar ist — **nicht**, ob die Mail vollständig ist. Ein
  /// abgeblendeter Knopf ist eine Behauptung ohne Begründung: Was fehlt, sagt
  /// die Prüfung beim Drücken, und zwar an dem Feld, das es behebt.
  /// Abgeblendet bleibt er nur, wo Drücken nichts bringen kann — während des
  /// Versands und ohne Postfach-Zugang (der Grund dafür steht schon oben im
  /// Dialog).
  bool get kannSenden =>
      phase == EmailVersandPhase.verfassen && (bereitschaft?.bereit ?? false);

  /// Der Entwurf braucht keinen Postfach-Zugang: Gesendet wird im
  /// Mailprogramm, nicht von der App. Genau deshalb ist er die Rückfalltür,
  /// wenn die Bereitschaft fehlt (§4.7).
  bool get kannEntwurfOeffnen => phase == EmailVersandPhase.verfassen;

  EmailEntwurfState copyWith({
    EmailEntwurf? entwurf,
    List<EmailEmpfaengerVorschlag>? vorschlaege,
    List<String>? ausOutlook,
    OutlookAnhaenge? outlookQuelle,
    bool? holtAusOutlook,
    int? anhangBytes,
    EmailVersandBereitschaft? bereitschaft,
    OutlookStand? outlookStand,
    EmailVersandPhase? phase,
    String? Function()? fehler,
    EmailVersandErgebnis? ergebnis,
    EmailEntwurfErgebnis? entwurfErgebnis,
    String? offenAn,
    String? offenKopie,
    bool? versandVersucht,
    bool? textSelbstGeschrieben,
    MailVorlage? Function()? gewaehlteVorlage,
    String? zusatzgruss,
    bool? mitleserImAn,
    Vorgang? Function()? vorgang,
    bool? wechseltVorgang,
    Anredebaustein? Function()? anredebaustein,
    bool? Function()? anredeNeutral,
    bool? anredePersoenlichMoeglich,
    Anrede? Function()? anredeGeschlecht,
    Anrede? mandantAnrede,
    bool? mandantBekannt,
    String? anredeImText,
    String? zusatzgrussImText,
  }) {
    return EmailEntwurfState(
      entwurf: entwurf ?? this.entwurf,
      vorschlaege: vorschlaege ?? this.vorschlaege,
      ausOutlook: ausOutlook ?? this.ausOutlook,
      outlookQuelle: outlookQuelle ?? this.outlookQuelle,
      holtAusOutlook: holtAusOutlook ?? this.holtAusOutlook,
      anhangBytes: anhangBytes ?? this.anhangBytes,
      bereitschaft: bereitschaft ?? this.bereitschaft,
      outlookStand: outlookStand ?? this.outlookStand,
      phase: phase ?? this.phase,
      fehler: fehler != null ? fehler() : this.fehler,
      ergebnis: ergebnis ?? this.ergebnis,
      entwurfErgebnis: entwurfErgebnis ?? this.entwurfErgebnis,
      offenAn: offenAn ?? this.offenAn,
      offenKopie: offenKopie ?? this.offenKopie,
      versandVersucht: versandVersucht ?? this.versandVersucht,
      textSelbstGeschrieben:
          textSelbstGeschrieben ?? this.textSelbstGeschrieben,
      // Wie bei `fehler` als Funktion: Die Vorlage muss sich auf null setzen
      // lassen („keine Vorlage"), und mit `?? this.` ginge das nie.
      gewaehlteVorlage: gewaehlteVorlage != null
          ? gewaehlteVorlage()
          : this.gewaehlteVorlage,
      zusatzgruss: zusatzgruss ?? this.zusatzgruss,
      mitleserImAn: mitleserImAn ?? this.mitleserImAn,
      // Wie bei `fehler` als Funktion: Der Vorgang muss sich im Dialog auf
      // null setzen lassen („kein Vorgang"), und mit `?? this.` ginge das nie.
      vorgang: vorgang != null ? vorgang() : this.vorgang,
      wechseltVorgang: wechseltVorgang ?? this.wechseltVorgang,
      // Beide als Funktion, wie `fehler`: Der Anredeanfang muss sich auf null
      // zuruecksetzen lassen (leerer Bestand), und bei `anredeNeutral` ist
      // null der Vorgabewert „wie der Empfaengerkreis es ergibt" — mit
      // `?? this.` waere er nach der ersten Wahl nicht mehr erreichbar.
      anredebaustein: anredebaustein != null
          ? anredebaustein()
          : this.anredebaustein,
      anredeNeutral: anredeNeutral != null
          ? anredeNeutral()
          : this.anredeNeutral,
      anredePersoenlichMoeglich:
          anredePersoenlichMoeglich ?? this.anredePersoenlichMoeglich,
      // Als Funktion, wie `fehler`: null ist hier der Vorgabewert „wie am
      // Mandanten hinterlegt" und muss nach einer Wahl wieder erreichbar
      // sein — beim Vorgangswechsel setzt der Cubit genau darauf zurueck.
      anredeGeschlecht: anredeGeschlecht != null
          ? anredeGeschlecht()
          : this.anredeGeschlecht,
      mandantAnrede: mandantAnrede ?? this.mandantAnrede,
      mandantBekannt: mandantBekannt ?? this.mandantBekannt,
      anredeImText: anredeImText ?? this.anredeImText,
      zusatzgrussImText: zusatzgrussImText ?? this.zusatzgrussImText,
    );
  }

  @override
  List<Object?> get props => [
    entwurf,
    vorschlaege,
    ausOutlook,
    outlookQuelle,
    holtAusOutlook,
    anhangBytes,
    bereitschaft,
    outlookStand,
    phase,
    fehler,
    ergebnis,
    entwurfErgebnis,
    offenAn,
    offenKopie,
    versandVersucht,
    textSelbstGeschrieben,
    gewaehlteVorlage,
    zusatzgruss,
    mitleserImAn,
    vorgang,
    wechseltVorgang,
    anredebaustein,
    anredeNeutral,
    anredePersoenlichMoeglich,
    anredeGeschlecht,
    mandantAnrede,
    mandantBekannt,
    anredeImText,
    zusatzgrussImText,
  ];
}
