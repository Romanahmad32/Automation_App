import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/ableitung_griff.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/anrede_griff.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/entwurf_quellen.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/outlook_anhaenge_griff.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/versand_griff.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/vorgang_griff.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
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
    with
        OutlookAnhaengeGriff,
        VersandGriff,
        AnredeGriff,
        VorgangGriff,
        AbleitungGriff {
  final EmailVersandRepository _repository;
  final VersichererCubit _versicherer;
  final EntwurfQuellen _quellen;

  /// Der Anredebestand (§7.1). Wie beim `VersichererCubit` holt der Entwurf
  /// ihn selbst: Sonst müsste ihn jede aufrufende Stelle durchreichen, und der
  /// Dialog geht aus zwei Tabs und einem weiteren Dialog auf.
  final AnredebausteineCubit _anreden;

  EmailEntwurfErzeuger? _erzeuger;
  KanzleiSettings _kanzlei = KanzleiSettings.empty;

  /// Die mitgegebene Zentralruf-Antwort (§4.3). Sie überlebt einen
  /// Vorgangswechsel: Sie gehört zu der Nachricht, die gerade beantwortet
  /// wird, nicht zum Vorgang — und sie ist im Postfach die einzige Quelle der
  /// Versichereradresse.
  ZentralrufReplyData? _antwort;

  /// Was die App selbst ins Feld „An" gesetzt hat — siehe `VorgangGriff`.
  List<String> _vorbelegt = const [];

  EmailEntwurfCubit(
    this._repository,
    UseCase<KanzleiSettings, NoParams> getKanzleiSettings,
    UseCase<List<Mandant>, NoParams> getMandanten,
    this._versicherer,
    this._anreden,
    UseCase<Mandant, Mandant> updateMandant,
  ) : _quellen = EntwurfQuellen(
        _repository,
        getKanzleiSettings,
        getMandanten,
        updateMandant,
      ),
      super(const EmailEntwurfState());

  @override
  EmailVersandRepository get versandRepository => _repository;

  @override
  String get absenderName => _kanzlei.name;

  @override
  EmailEntwurfErzeuger? get anredeErzeuger => _erzeuger;

  @override
  List<String> get vorbelegteEmpfaenger => _vorbelegt;

  @override
  set vorbelegteEmpfaenger(List<String> adressen) => _vorbelegt = adressen;

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
    // Beides nebeneinander: Die Kanzleidaten kommen aus den Einstellungen, der
    // Anredebestand aus seinem Singleton — der zweite ist beim zweiten Öffnen
    // schon da (`ladenWennNoetig`).
    await (
      _quellen.kanzlei().then((k) => _kanzlei = k),
      _anreden.ladenWennNoetig(),
    ).wait;
    _antwort = antwort;
    final erzeuger = await erzeugerFuer(vorgang, mandant: mandant);

    // Der Dialog lässt sich abbrechen, solange hier noch gewartet wird — dann
    // ist der Cubit zu, und ein `emit` darauf wirft. Nach jedem `await` deshalb
    // erst fragen, ob es den Entwurf überhaupt noch gibt.
    if (isClosed) return;
    // Vorbelegt aus dem Mandanten (§5.1), aenderbar je Mail (§4.7): Der
    // Regelfall soll ohne Klick stimmen.
    final gruss = erzeuger.mandant?.persoenlicheGrussformel.trim() ?? '';
    // Die Anrede ebenso: der erste des Bestands, ab Werk „Sehr geehrter" —
    // also genau die Anrede, die die App vorher fest erzeugt hat. Die Beugung
    // folgt dem Mandanten (§7.1), ein Klick ist nur fuer die Ausnahme noetig.
    final anrede = _anreden.state.vorgabe;
    final entwurf = erzeuger.entwurfMit(
      anhangPfade,
      zusatzgruss: gruss,
      anredebaustein: anrede,
    );
    // Diese Adressen hat die App gesetzt; nur sie gehen bei einem
    // Vorgangswechsel wieder mit (`EmpfaengerAbgleich`).
    _vorbelegt = entwurf.an;
    emit(
      state.copyWith(
        entwurf: entwurf,
        vorschlaege: erzeuger.vorschlaege,
        zusatzgruss: gruss,
        anredebaustein: () => anrede,
        vorgang: () => vorgang,
        // Was das Register sagt, damit die Chipreihe zeigt, welche Form
        // ohne Klick gilt (§5.1); gewaehlt ist zunaechst nichts.
        mandantAnrede: erzeuger.mandant?.anrede ?? Anrede.keine,
        mandantBekannt: erzeuger.mandant != null,
        mitleserImAn: erzeuger.liestJemandMit(entwurf.alleEmpfaenger),
        anredePersoenlichMoeglich: erzeuger.anredePersoenlichMoeglich(
          entwurf.alleEmpfaenger,
        ),
        // Woertlich mitschreiben, was `entwurfMit` in den Text gesetzt hat —
        // dieselbe Rechnung ueber dieselbe Empfaengerliste, deshalb derselbe
        // Aufruf. Ohne das fand `AbleitungGriff` die Stelle nie und lief still
        // leer, sobald der Anwalt **zuerst** tippte und danach einen Chip
        // klickte (behoben am 02.09.2026). Dass `entwurfMit` ebenfalls ueber
        // `alleEmpfaenger` rechnet und nicht ueber die Vorschlagsliste, ist
        // seit dem 03.09.2026 zugesichert und nicht mehr nur zufaellig wahr.
        anredeImText: erzeuger.anredeFuer(
          entwurf.alleEmpfaenger,
          baustein: anrede,
        ),
        zusatzgrussImText: gruss,
      ),
    );

    // Eine im Ladefenster gewaehlte Vorlage nachziehen: `leiteAb` hat sie
    // damals verworfen, weil der Erzeuger noch fehlte. Jetzt steht er — sonst
    // blieb die Wahl wirkungslos, bis der Anwalt etwas anderes anfasst.
    if (state.gewaehlteVorlage != null) leiteAb(betreffAuch: true);

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

  /// Schreibt die Anredeart ins Register und zieht den Erzeuger nach; null
  /// heißt: hat nicht geklappt. Die Entscheidung, **ob** nachgetragen wird,
  /// trifft `AnredeGriff` am Zustand — hier steht nur der Weg dorthin.
  @override
  Future<Mandant?> anredeartNachtragen(Mandant mandant, Anrede anrede) async {
    final gemerkt = await _quellen.merkeAnredeart(mandant, anrede);
    if (gemerkt == null) return null;
    // Sonst behauptet der Erzeuger weiter „keine Angabe" — und die Ableitung
    // fragt ihn.
    await erzeugerFuer(state.vorgang, mandant: gemerkt);
    return gemerkt;
  }

  /// Der beim Verfassen gewählte Zusatzgruß (§4.7); leer heisst keiner.
  void setzeZusatzgruss(String gruss) {
    emit(state.copyWith(zusatzgruss: gruss));
    leiteAb(betreffAuch: true);
  }

  void empfaengerHinzufuegen(String adresse) =>
      setzeEntwurf(state.entwurf.mitEmpfaenger(adresse));

  void kopieHinzufuegen(String adresse) =>
      setzeEntwurf(state.entwurf.mitKopie(adresse));

  void empfaengerEntfernen(String adresse) =>
      setzeEntwurf(state.entwurf.ohneEmpfaenger(adresse));

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
      setzeEntwurf(state.entwurf.mitAnhang(pfad));

  /// Nimmt ein Signaturbild für diese eine Mail heraus — oder wieder hinein.
  /// Die Signatur in den Einstellungen bleibt, wie sie ist (§4.7).
  void signaturBildUmschalten(String dateiname) =>
      setzeEntwurf(state.entwurf.mitUmgeschaltetemSignaturBild(dateiname));

  /// Benennt den Anhang **fuer die Mail** um; die Datei in der Akte behaelt
  /// ihren Namen.
  void anhangUmbenennen(String pfad, String name) =>
      emit(state.copyWith(entwurf: state.entwurf.mitAnhangName(pfad, name)));

  void anhangEntfernen(String pfad) =>
      setzeEntwurf(state.entwurf.ohneAnhang(pfad));

  /// Nimmt auf, was in einer Empfängerzeile steht, aber noch nicht übernommen
  /// ist. Der Zustand muss es kennen, damit die Prüfung beim Senden es sieht —
  /// eine eingetippte, nicht übernommene Adresse ginge sonst still verloren.
  void setzeOffeneEingabe({String? an, String? kopie}) =>
      emit(state.copyWith(offenAn: an, offenKopie: kopie));

  /// Der Erzeuger zu einem Vorgang, samt Mandant aus dem Register — und
  /// gemerkt, weil `fuellerFuer` und die Ableitung ihn brauchen. [mandant]
  /// überschreibt den Registerzugriff für Aufrufer, die ihn zur Hand haben.
  @override
  Future<EmailEntwurfErzeuger> erzeugerFuer(
    Vorgang? vorgang, {
    Mandant? mandant,
  }) async {
    final erzeuger = EmailEntwurfErzeuger(
      kanzlei: _kanzlei,
      vorgang: vorgang,
      mandant: mandant ?? await _quellen.mandantZu(vorgang),
      antwort: _antwort,
      versicherer: _versicherer.state,
    );
    _erzeuger = erzeuger;
    return erzeuger;
  }
}
