import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
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
class EmailEntwurfCubit extends Cubit<EmailEntwurfState> {
  final EmailVersandRepository _repository;
  final UseCase<KanzleiSettings, NoParams> _getKanzleiSettings;
  final UseCase<List<Mandant>, NoParams> _getMandanten;
  final VersichererCubit _versicherer;

  EmailEntwurfErzeuger? _erzeuger;
  KanzleiSettings _kanzlei = KanzleiSettings.empty;

  EmailEntwurfCubit(
    this._repository,
    this._getKanzleiSettings,
    this._getMandanten,
    this._versicherer,
  ) : super(const EmailEntwurfState());

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
    _kanzlei = await _ladeKanzlei();
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: _kanzlei,
      vorgang: vorgang,
      mandant: mandant ?? await _mandantZu(vorgang),
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

    final bereitschaft = await _ladeBereitschaft();
    if (isClosed) return;
    emit(state.copyWith(bereitschaft: bereitschaft));
  }

  /// Kein Zugang, keine Antwort vom Dienst: Der Anwalt soll das sehen, bevor er
  /// tippt — und nicht erst, wenn er auf „Senden" drückt.
  Future<EmailVersandBereitschaft> _ladeBereitschaft() async {
    try {
      return await _repository.ladeBereitschaft();
    } catch (e) {
      return EmailVersandBereitschaft(
        bereit: false,
        hinweis: 'Der Postausgang ist nicht erreichbar: ${ausnahmeText(e)}',
      );
    }
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

  /// Holt die Anhänge aus der Nachricht, die in Outlook gerade offen ist, und
  /// **bietet** sie an (§4.7). Angehängt werden sie erst auf Klick — wie die
  /// Dateien aus dem Fall-Ordner.
  ///
  /// Meldet beides: was in der Nachricht hing und was davon neu ist. Wer
  /// zweimal drückt, soll „liegt schon da" zu sehen bekommen und nicht ein
  /// Fenster, in dem sich nichts rührt. Null heißt: gescheitert, der Grund
  /// steht im Zustand.
  Future<({int gefunden, int neu})?> anhaengeAusOutlook() async {
    if (state.holtAusOutlook) return null;
    emit(state.copyWith(holtAusOutlook: true, fehler: () => null));

    try {
      final geholt = await _repository.ladeOutlookAnhaenge();

      // Was schon angehängt oder schon angeboten ist, nicht doppelt zeigen.
      // Der Dienst legt je Nachricht denselben Pfad an, deshalb trägt der
      // Vergleich auch beim zweiten Griff nach derselben Mail.
      final bekannt = {...state.ausOutlook, ...state.entwurf.anhangPfade};
      final neu = geholt.where((pfad) => !bekannt.contains(pfad)).toList();
      if (isClosed) return (gefunden: geholt.length, neu: neu.length);

      emit(
        state.copyWith(
          holtAusOutlook: false,
          ausOutlook: [...state.ausOutlook, ...neu],
        ),
      );
      return (gefunden: geholt.length, neu: neu.length);
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(holtAusOutlook: false, fehler: () => ausnahmeText(e)),
      );
      return null;
    }
  }

  /// Nimmt einen aus Outlook geholten Vorschlag aus der Reihe **und** loescht
  /// die zwischengelagerte Datei: Was der Anwalt verwirft, soll nicht in der
  /// Ablage liegen bleiben. Der Rueckweg bleibt das erneute Holen — die
  /// Nachricht liegt ja weiter im Postfach.
  void outlookAnhangVerwerfen(String pfad) {
    emit(
      state.copyWith(
        ausOutlook: state.ausOutlook
            .where((vorhanden) => vorhanden != pfad)
            .toList(),
      ),
    );
    unawaited(_repository.verwirfAnhang(pfad));
  }

  /// Benennt den Anhang **fuer die Mail** um; die Datei in der Akte behaelt
  /// ihren Namen.
  void anhangUmbenennen(String pfad, String name) =>
      emit(state.copyWith(entwurf: state.entwurf.mitAnhangName(pfad, name)));

  void anhangEntfernen(String pfad) =>
      _setzeEntwurf(state.entwurf.ohneAnhang(pfad));

  /// Sendet und meldet, ob es geklappt hat. Bei einem Fehler ist nichts
  /// hinausgegangen — der Entwurf bleibt vollständig erhalten, damit der
  /// Anwalt nach der Ursache nur noch einmal auf „Senden" drücken muss.
  Future<bool> senden() async {
    if (!state.kannSenden) return false;
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
    if (!state.kannEntwurfOeffnen) return null;
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
    emit(state.copyWith(entwurf: angepasst, fehler: () => null));
  }

  /// Ohne Kanzleidaten fehlt nur die Unterschrift unter dem Entwurf — kein
  /// Grund, den Versand zu verweigern.
  Future<KanzleiSettings> _ladeKanzlei() async {
    final ergebnis = await _getKanzleiSettings(const NoParams());
    return switch (ergebnis) {
      Right(value: final settings) => settings,
      Left() => KanzleiSettings.empty,
    };
  }

  /// Der am Vorgang hinterlegte Mandant. Fehlt er oder ist das Register nicht
  /// erreichbar, entfällt nur sein Adressvorschlag — der Entwurf steht
  /// trotzdem.
  Future<Mandant?> _mandantZu(Vorgang? vorgang) async {
    final id = vorgang?.mandantId;
    if (id == null) return null;

    final ergebnis = await _getMandanten(const NoParams());
    return switch (ergebnis) {
      Right(value: final mandanten) =>
        mandanten.where((eintrag) => eintrag.id == id).firstOrNull,
      Left() => null,
    };
  }
}
