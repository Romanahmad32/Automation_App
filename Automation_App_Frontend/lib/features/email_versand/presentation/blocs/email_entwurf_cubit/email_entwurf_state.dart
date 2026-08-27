import 'package:automation_app/features/email_versand/domain/entities/email_empfaenger_vorschlag.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
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

  /// True, solange Outlook nach seinen Anhängen gefragt wird.
  final bool holtAusOutlook;

  /// Was die Anhänge zusammen wiegen. Einmal beim Ändern gemessen und nicht
  /// bei jedem Neubau: Das Formular baut bei jedem Anschlag neu, und ein
  /// Plattenzugriff je Anhang und Tastendruck wäre teuer für eine Zahl, die
  /// sich beim Tippen nicht ändert.
  final int anhangBytes;

  /// Ob überhaupt gesendet werden kann; null, solange nicht abgefragt.
  final EmailVersandBereitschaft? bereitschaft;

  final EmailVersandPhase phase;

  /// Meldung des letzten fehlgeschlagenen Versuchs im Klartext. Bleibt stehen,
  /// bis der Anwalt etwas ändert — sie sagt ihm, was zu tun ist.
  final String? fehler;

  final EmailVersandErgebnis? ergebnis;

  /// Der zuletzt ans Mailprogramm übergebene Entwurf. Bleibt stehen, damit
  /// der Dialog sagen kann, dass die Mail dort liegt — und der Anwalt sie
  /// nicht versehentlich ein zweites Mal übergibt oder gar direkt sendet.
  final EmailEntwurfErgebnis? entwurfErgebnis;

  /// True, sobald der Anwalt den Text selbst angefasst hat. Danach schreibt die
  /// automatische Anrede ihn nicht mehr um — sonst verlöre er beim Hinzufügen
  /// eines Empfängers, was er schon getippt hat.
  final bool textSelbstGeschrieben;

  const EmailEntwurfState({
    this.entwurf = const EmailEntwurf(),
    this.vorschlaege = const [],
    this.ausOutlook = const [],
    this.holtAusOutlook = false,
    this.anhangBytes = 0,
    this.bereitschaft,
    this.phase = EmailVersandPhase.verfassen,
    this.fehler,
    this.ergebnis,
    this.entwurfErgebnis,
    this.textSelbstGeschrieben = false,
  });

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

  bool get kannSenden =>
      phase == EmailVersandPhase.verfassen &&
      entwurf.istSendbar &&
      !ueberGrenze &&
      (bereitschaft?.bereit ?? false);

  /// Der Entwurf braucht keinen Postfach-Zugang: Gesendet wird im
  /// Mailprogramm, nicht von der App. Genau deshalb ist er die Rückfalltür,
  /// wenn die Bereitschaft fehlt (§4.7).
  bool get kannEntwurfOeffnen =>
      phase == EmailVersandPhase.verfassen && entwurf.istSendbar;

  EmailEntwurfState copyWith({
    EmailEntwurf? entwurf,
    List<EmailEmpfaengerVorschlag>? vorschlaege,
    List<String>? ausOutlook,
    bool? holtAusOutlook,
    int? anhangBytes,
    EmailVersandBereitschaft? bereitschaft,
    EmailVersandPhase? phase,
    String? Function()? fehler,
    EmailVersandErgebnis? ergebnis,
    EmailEntwurfErgebnis? entwurfErgebnis,
    bool? textSelbstGeschrieben,
  }) {
    return EmailEntwurfState(
      entwurf: entwurf ?? this.entwurf,
      vorschlaege: vorschlaege ?? this.vorschlaege,
      ausOutlook: ausOutlook ?? this.ausOutlook,
      holtAusOutlook: holtAusOutlook ?? this.holtAusOutlook,
      anhangBytes: anhangBytes ?? this.anhangBytes,
      bereitschaft: bereitschaft ?? this.bereitschaft,
      phase: phase ?? this.phase,
      fehler: fehler != null ? fehler() : this.fehler,
      ergebnis: ergebnis ?? this.ergebnis,
      entwurfErgebnis: entwurfErgebnis ?? this.entwurfErgebnis,
      textSelbstGeschrieben:
          textSelbstGeschrieben ?? this.textSelbstGeschrieben,
    );
  }

  @override
  List<Object?> get props => [
    entwurf,
    vorschlaege,
    ausOutlook,
    holtAusOutlook,
    anhangBytes,
    bereitschaft,
    phase,
    fehler,
    ergebnis,
    entwurfErgebnis,
    textSelbstGeschrieben,
  ];
}
