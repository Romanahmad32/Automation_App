import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlagen_fueller.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/entwurf_quellen.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/outlook_anhaenge_griff.dart';
import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Führt den Mail-Entwurf (§4.7): vorbelegen, ändern, senden. Bewusst eine
/// Factory — je Dialog ein eigener Entwurf, damit ein abgebrochener Versuch
/// nicht im nächsten Vorgang wieder auftaucht.
///
/// Die Kanzleidaten holt der Cubit selbst. Sonst müsste sie jede aufrufende
/// Stelle durchreichen, und der Dialog wird von zwei Tabs aus geöffnet, deren
/// Blocs nichts miteinander zu tun haben.
@injectable
class EmailEntwurfCubit extends Cubit<EmailEntwurfState>
    with OutlookAnhaengeGriff {
  final EmailVersandRepository _repository;
  final VersichererCubit _versicherer;
  final EntwurfQuellen _quellen;

  EmailEntwurfErzeuger? _erzeuger;
  KanzleiSettings _kanzlei = KanzleiSettings.empty;

  EmailEntwurfCubit(
    this._repository,
    UseCase<KanzleiSettings, NoParams> getKanzleiSettings,
    UseCase<List<Mandant>, NoParams> getMandanten,
    this._versicherer,
  ) : _quellen = EntwurfQuellen(_repository, getKanzleiSettings, getMandanten),
      super(const EmailEntwurfState());

  @override
  EmailVersandRepository get versandRepository => _repository;

  /// Legt den vorbelegten Entwurf an und fragt nebenbei, ob überhaupt gesendet
  /// werden kann. Die Bereitschaft steht damit auf dem Schirm, bevor der Anwalt
  /// den ersten Satz getippt hat.
  ///
  /// Ohne [vorgang] und ohne Anhänge entsteht ein leeres Anschreiben — Anrede
  /// und Grußformel stehen, alles andere schreibt der Anwalt.
  ///
  /// [mandant] ist optional: Wer ihn zur Hand hat, spart den Zugriff aufs
  /// Register; sonst löst der Cubit ihn aus dem Vorgang auf. Ohne diesen Weg
  /// müsste jede aufrufende Stelle das Register selbst befragen, nur damit die
  /// Mandantenadresse im Entwurf auftaucht.
  Future<void> starte({
    Vorgang? vorgang,
    Mandant? mandant,
    ZentralrufReplyData? antwort,
    List<String> anhangPfade = const [],
  }) async {
    _kanzlei = await _quellen.kanzlei();
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: _kanzlei,
      vorgang: vorgang,
      mandant: mandant ?? await _quellen.mandantZu(vorgang),
      antwort: antwort,
      versicherer: _versicherer.state,
    );
    _erzeuger = erzeuger;

    // Der Dialog lässt sich abbrechen, solange hier noch gewartet wird — dann
    // ist der Cubit zu, und ein `emit` darauf wirft. Nach jedem `await` deshalb
    // erst fragen, ob es den Entwurf überhaupt noch gibt.
    if (isClosed) return;
    // Vorbelegt aus dem Mandanten (§5.1), aenderbar je Mail (§4.7): Der
    // Regelfall soll ohne Klick stimmen.
    final gruss = erzeuger.mandant?.persoenlicheGrussformel.trim() ?? '';
    final entwurf = erzeuger.entwurfMit(anhangPfade, zusatzgruss: gruss);
    emit(
      state.copyWith(
        entwurf: entwurf,
        vorschlaege: erzeuger.vorschlaege,
        zusatzgruss: gruss,
        grussMoeglich: erzeuger.nurAnDenMandanten(entwurf.alleEmpfaenger),
      ),
    );

    // Outlook im Hintergrund hochfahren, während der Anwalt tippt. Bewusst
    // ohne await: Der Entwurf steht schon, und ob es klappt, ändert hier
    // nichts (§4.7).
    unawaited(_repository.waermeEntwurfVor());

    // Beides nebeneinander: Der Postausgang wird befragt, der Outlook-Stand
    // liegt beim Dienst schon bereit (er sieht beim Start einmal nach).
    final auskuenfte = await (
      _quellen.bereitschaft(),
      _quellen.outlookStand(),
    ).wait;
    if (isClosed) return;
    emit(
      state.copyWith(bereitschaft: auskuenfte.$1, outlookStand: auskuenfte.$2),
    );
  }

  /// Übernimmt eine gewählte Mail-Textvorlage (§4.7) — oder **keine**:
  /// [vorlage] null führt zur Vorbelegung aus den Vorgangsdaten zurück. Eine
  /// Wahl, die sich nicht zurücknehmen lässt, zwänge zum Schliessen und
  /// Neuöffnen des Entwurfs.
  ///
  /// Betreff und Text sind danach **abgeleitet**, nicht getippt: Sie werden
  /// nachgezogen, wenn sich Empfänger oder Zusatzgruß ändern. Erst wenn der
  /// Anwalt selbst in den Text schreibt ([setzeText]), hört das auf.
  void waehleVorlage(MailVorlage? vorlage) {
    emit(state.copyWith(gewaehlteVorlage: () => vorlage));
    _leiteAb(betreffAuch: true);
  }

  /// Der beim Verfassen gewählte Zusatzgruß (§4.7); leer heisst keiner.
  void setzeZusatzgruss(String gruss) {
    emit(state.copyWith(zusatzgruss: gruss));
    _leiteAb(betreffAuch: true);
  }

  /// Leitet Betreff und Text aus dem ab, was gerade gilt: gewählte Vorlage,
  /// Empfänger, Zusatzgruß. [betreffAuch] trennt die **ausdrückliche**
  /// Handlung (Vorlage oder Gruß gewählt — dann darf auch der Betreff neu
  /// entstehen) von der beiläufigen (ein Empfänger kam dazu — dann bleibt der
  /// Betreff stehen, wie es hier schon immer war).
  void _leiteAb({required bool betreffAuch}) {
    if (state.textSelbstGeschrieben) return;
    final abgeleitet = _abgeleitet(state.entwurf, betreffAuch: betreffAuch);
    emit(state.copyWith(entwurf: abgeleitet));
  }

  /// Der Entwurf mit abgeleitetem Text — und auf Wunsch abgeleitetem Betreff.
  EmailEntwurf _abgeleitet(EmailEntwurf entwurf, {required bool betreffAuch}) {
    final erzeuger = _erzeuger;
    if (erzeuger == null) return entwurf;

    final empfaenger = entwurf.alleEmpfaenger;
    final nurMandant = erzeuger.nurAnDenMandanten(empfaenger);
    final gruss = nurMandant ? state.zusatzgruss : '';
    final vorlage = state.gewaehlteVorlage;

    if (vorlage == null) {
      return entwurf.copyWith(
        text: erzeuger.textFuer(
          empfaenger,
          mitSchreiben: entwurf.anhangPfade.isNotEmpty,
          zusatzgruss: gruss,
        ),
      );
    }

    final gefuellt = fuellerFuer(empfaenger).fuelleVorlage(vorlage);
    return entwurf.copyWith(
      betreff: betreffAuch ? gefuellt.betreff : entwurf.betreff,
      text: gefuellt.text,
    );
  }

  /// Der Füller zum aktuellen Stand. Öffentlich, weil die
  /// Platzhalter-Übersicht im Dialog dieselben Werte zeigen muss, die in den
  /// Text gehen — eine zweite Rechnung daneben liefe auseinander.
  MailVorlagenFueller fuellerFuer(List<String> empfaenger) {
    final erzeuger = _erzeuger!;
    final nurMandant = erzeuger.nurAnDenMandanten(empfaenger);
    return MailVorlagenFueller(
      anrede: erzeuger.anredeFuer(empfaenger),
      nurAnDenMandanten: nurMandant,
      grussformel: nurMandant ? state.zusatzgruss : '',
      vorgang: erzeuger.vorgang,
      mandant: erzeuger.mandant,
    );
  }

  void empfaengerHinzufuegen(String adresse) =>
      _setzeEntwurf(state.entwurf.mitEmpfaenger(adresse));

  void kopieHinzufuegen(String adresse) =>
      _setzeEntwurf(state.entwurf.mitKopie(adresse));

  void empfaengerEntfernen(String adresse) =>
      _setzeEntwurf(state.entwurf.ohneEmpfaenger(adresse));

  void setzeBetreff(String betreff) {
    emit(state.copyWith(entwurf: state.entwurf.copyWith(betreff: betreff)));
  }

  /// Ab hier gehört der Text dem Anwalt: Anrede und Bezugssatz werden nicht
  /// mehr nachgezogen, wenn sich Empfänger oder Anhänge ändern.
  void setzeText(String text) {
    emit(
      state.copyWith(
        entwurf: state.entwurf.copyWith(text: text),
        textSelbstGeschrieben: true,
      ),
    );
  }

  void anhangHinzufuegen(String pfad) =>
      _setzeEntwurf(state.entwurf.mitAnhang(pfad));

  /// Nimmt ein Signaturbild für diese eine Mail heraus — oder wieder hinein.
  /// Die Signatur in den Einstellungen bleibt, wie sie ist (§4.7).
  void signaturBildUmschalten(String dateiname) =>
      _setzeEntwurf(state.entwurf.mitUmgeschaltetemSignaturBild(dateiname));

  /// Benennt den Anhang **fuer die Mail** um; die Datei in der Akte behaelt
  /// ihren Namen.
  void anhangUmbenennen(String pfad, String name) =>
      emit(state.copyWith(entwurf: state.entwurf.mitAnhangName(pfad, name)));

  void anhangEntfernen(String pfad) =>
      _setzeEntwurf(state.entwurf.ohneAnhang(pfad));

  /// Nimmt auf, was in einer Empfängerzeile steht, aber noch nicht übernommen
  /// ist. Der Zustand muss es kennen, damit die Prüfung beim Senden es sieht —
  /// eine eingetippte, nicht übernommene Adresse ginge sonst still verloren.
  void setzeOffeneEingabe({String? an, String? kopie}) =>
      emit(state.copyWith(offenAn: an, offenKopie: kopie));

  /// Merkt sich den Versuch und meldet, ob die Mail hinaus kann. Ab jetzt
  /// markiert das Formular, was fehlt (§4.7): Der Knopf ist anfassbar, und die
  /// Begründung kommt beim Drücken statt als dauerhafter Kasten über dem
  /// Formular.
  bool istVersandbereit() {
    emit(state.copyWith(versandVersucht: true));
    return state.pruefung.vollstaendig;
  }

  /// Sendet und meldet, ob es geklappt hat. Bei einem Fehler ist nichts
  /// hinausgegangen — der Entwurf bleibt vollständig erhalten, damit der
  /// Anwalt nach der Ursache nur noch einmal auf „Senden" drücken muss.
  Future<bool> senden() async {
    if (!state.kannSenden || !state.pruefung.vollstaendig) return false;
    emit(state.copyWith(phase: EmailVersandPhase.sendet, fehler: () => null));

    try {
      final ergebnis = await _repository.sende(
        state.entwurf,
        absenderName: _kanzlei.name,
      );
      // Ist der Entwurf inzwischen weg, bleibt die Mail trotzdem versendet —
      // nur zu melden ist es niemandem mehr.
      if (isClosed) return true;
      emit(
        state.copyWith(phase: EmailVersandPhase.gesendet, ergebnis: ergebnis),
      );
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          phase: EmailVersandPhase.verfassen,
          fehler: () => ausnahmeText(e),
        ),
      );
      return false;
    }
  }

  /// Übergibt den Entwurf ans Mailprogramm, statt zu senden (§4.7). Gesendet
  /// wird dort von Hand — deshalb schaltet die Phase **nicht** auf `gesendet`:
  /// Was die App nicht weiß, darf sie im Abschlussdialog nicht behaupten.
  Future<EmailEntwurfErgebnis?> entwurfOeffnen() async {
    if (!state.kannEntwurfOeffnen || !state.pruefung.vollstaendig) return null;
    emit(
      state.copyWith(phase: EmailVersandPhase.uebergibt, fehler: () => null),
    );

    try {
      final ergebnis = await _repository.oeffneEntwurf(
        state.entwurf,
        absenderName: _kanzlei.name,
      );
      if (isClosed) return ergebnis;
      emit(
        state.copyWith(
          phase: EmailVersandPhase.verfassen,
          entwurfErgebnis: ergebnis,
        ),
      );
      return ergebnis;
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          phase: EmailVersandPhase.verfassen,
          fehler: () => ausnahmeText(e),
        ),
      );
      return null;
    }
  }

  /// Übernimmt den geänderten Entwurf und zieht den Text nach, solange der
  /// Anwalt ihn noch nicht selbst angefasst hat — mit Vorlage durch die
  /// Vorlage, ohne durch die Vorbelegung.
  ///
  /// Der **Betreff bleibt stehen**: Ein hinzugefügter Empfänger ist keine
  /// Ansage, die Betreffzeile neu zu schreiben.
  void _setzeEntwurf(EmailEntwurf entwurf) {
    final angepasst = state.textSelbstGeschrieben
        ? entwurf
        : _abgeleitet(entwurf, betreffAuch: false);
    emit(
      state.copyWith(
        entwurf: angepasst,
        anhangBytes: AnhangDarstellung.summe(angepasst.anhangPfade),
        grussMoeglich:
            _erzeuger?.nurAnDenMandanten(angepasst.alleEmpfaenger) ?? false,
        fehler: () => null,
      ),
    );
  }
}
