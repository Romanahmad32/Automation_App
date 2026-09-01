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
    emit(
      state.copyWith(
        entwurf: erzeuger.entwurfMit(anhangPfade),
        vorschlaege: erzeuger.vorschlaege,
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

  /// Übernimmt eine gewählte Mail-Textvorlage (§4.7): Betreff und Text kommen
  /// aus ihr, die `{{Platzhalter}}` füllt [MailVorlagenFueller] aus Vorgang
  /// und Mandant.
  ///
  /// Danach gilt der Text als selbst geschrieben — die automatische Anrede
  /// zieht ihn nicht mehr nach. Sie täte es beim nächsten Empfänger, den der
  /// Anwalt hinzufügt, und die eben gewählte Vorlage wäre wieder weg.
  ///
  /// **Die Anrede der Vorlage richtet sich nach dem Feld „An" in diesem
  /// Augenblick.** Wer die Vorlage wählt und danach die Versicherung
  /// hinzunimmt, hat eine Mandantenanrede vor einem Mitleser stehen — das
  /// sieht er im Text und ändert es; die App schreibt ihm nicht hinein.
  void waehleVorlage(MailVorlage vorlage) {
    final erzeuger = _erzeuger;
    if (erzeuger == null) return;

    final empfaenger = state.entwurf.an;
    final gefuellt = MailVorlagenFueller(
      anrede: erzeuger.anredeFuer(empfaenger),
      nurAnDenMandanten: erzeuger.nurAnDenMandanten(empfaenger),
      vorgang: erzeuger.vorgang,
      mandant: erzeuger.mandant,
    ).fuelleVorlage(vorlage);

    emit(
      state.copyWith(
        entwurf: state.entwurf.copyWith(
          betreff: gefuellt.betreff,
          text: gefuellt.text,
        ),
        textSelbstGeschrieben: true,
        gewaehlteVorlageId: vorlage.id,
      ),
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

  /// Übernimmt den geänderten Entwurf und zieht Anrede und Bezugssatz nach,
  /// solange der Anwalt den Text noch nicht selbst angefasst hat.
  void _setzeEntwurf(EmailEntwurf entwurf) {
    final erzeuger = _erzeuger;
    final angepasst = state.textSelbstGeschrieben || erzeuger == null
        ? entwurf
        : entwurf.copyWith(
            text: erzeuger.textFuer(
              entwurf.alleEmpfaenger,
              mitSchreiben: entwurf.anhangPfade.isNotEmpty,
            ),
          );
    emit(
      state.copyWith(
        entwurf: angepasst,
        anhangBytes: AnhangDarstellung.summe(angepasst.anhangPfade),
        fehler: () => null,
      ),
    );
  }
}
