import 'package:automation_app/features/email_versand/domain/entities/email_empfaenger_vorschlag.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_pruefung.dart';
import 'package:automation_app/features/email_versand/domain/services/versand_voraussetzungen.dart';
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

  /// Ob ausschliesslich der Mandant angeschrieben wird — nur dann geht der
  /// Zusatzgruß mit. Steht im Zustand statt in der Oberfläche, weil dieselbe
  /// Regel den Text erzeugt und die Chips sperrt; zwei Rechnungen davon liefen
  /// auseinander.
  final bool grussMoeglich;

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
    this.grussMoeglich = false,
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
  /// der beiden Wege.
  bool get beschaeftigt => sendetGerade || uebergibtGerade;

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
    bool? grussMoeglich,
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
      grussMoeglich: grussMoeglich ?? this.grussMoeglich,
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
    grussMoeglich,
  ];
}
