import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/domain/services/entwurf_ableitung.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlagen_fueller.dart';
import 'package:automation_app/features/email_versand/domain/services/text_nachtrag.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Woher Betreff und Text des Entwurfs kommen (§4.7) — eigener Baustein neben
/// `VersandGriff`, `AnredeGriff` und `VorgangGriff`.
///
/// Er steht für sich, weil hier **eine** Frage zusammenläuft, die überall im
/// Dialog auftaucht: Gehört der Text noch der Ableitung oder schon dem Anwalt?
/// Jede Antwort darauf hat zwei Hälften — ableiten *oder* nachtragen —, und die
/// beiden Merker im Zustand (`anredeImText`, `zusatzgrussImText`) sind die
/// Naht dazwischen. Sie an einer Stelle zu halten ist der Grund für diesen
/// Schnitt: Verstreut haben sie schon zweimal auseinandergelaufen.
mixin AbleitungGriff on Cubit<EmailEntwurfState> {
  /// Der Erzeuger zum aktuellen Vorgang; null, solange der Dialog lädt.
  /// Dieselbe Zusage wie in `AnredeGriff` — wer beide Mixins einhängt, erfüllt
  /// sie einmal.
  EmailEntwurfErzeuger? get anredeErzeuger;

  /// Die Ableitung zum aktuellen Stand; null, solange kein Erzeuger steht.
  EntwurfAbleitung? get ableitung {
    final erzeuger = anredeErzeuger;
    if (erzeuger == null) return null;
    return EntwurfAbleitung(
      erzeuger: erzeuger,
      vorlage: state.gewaehlteVorlage,
      zusatzgruss: state.zusatzgruss,
      anredebaustein: state.anredebaustein,
      anredeNeutral: state.anredeNeutral,
      geschlecht: state.anredeGeschlecht,
    );
  }

  /// Leitet Betreff und Text neu ab — die Regeln stehen in
  /// [EntwurfAbleitung]. Solange der Erzeuger fehlt (der Dialog lädt noch),
  /// bleibt der Entwurf, wie er ist.
  ///
  /// **Hat der Anwalt selbst getippt, wird nicht mehr abgeleitet, aber auch
  /// nicht nichts getan:** Dann trägt [_zieheNach] Anrede und Zusatzgruß
  /// gezielt an ihrer Stelle nach. Vorher liefen die Chips dort still leer.
  void leiteAb({required bool betreffAuch}) {
    final stand = ableitung;
    if (stand == null) return;
    if (state.textSelbstGeschrieben) {
      _zieheNach(stand);
      return;
    }
    final entwurf = stand.abgeleitet(state.entwurf, betreffAuch: betreffAuch);
    emit(
      state.copyWith(
        entwurf: entwurf,
        // Woertlich mitschreiben, was in den Text gegangen ist: Genau daran
        // findet [_zieheNach] die Stelle wieder, sobald der Anwalt selbst
        // getippt hat.
        anredeImText: stand.anredeFuer(entwurf.alleEmpfaenger),
        zusatzgrussImText: state.zusatzgruss,
      ),
    );
  }

  /// Übernimmt eine gewählte Mail-Textvorlage (§4.7) — oder **keine**:
  /// [vorlage] null führt zur Vorbelegung aus den Vorgangsdaten zurück. Eine
  /// Wahl, die sich nicht zurücknehmen lässt, zwänge zum Schliessen und
  /// Neuöffnen des Entwurfs.
  ///
  /// Betreff und Text sind danach **abgeleitet**, nicht getippt: Sie werden
  /// nachgezogen, wenn sich Empfänger oder Zusatzgruß ändern. Erst wenn der
  /// Anwalt selbst in den Text schreibt (`setzeText`), hört das auf.
  ///
  /// **Beim Abwählen geht der Betreff mit** (behoben am 03.09.2026): Sonst
  /// blieb er als einziger Rest der Vorlage über einem Text stehen, der schon
  /// wieder aus der Vorbelegung kam — „Ihre Verkehrsunfallsache Müller ./. HUK
  /// · Unser Zeichen: 84/26" über dem leeren Anschreiben, und so ging die Mail
  /// hinaus. [EntwurfAbleitung.abgeleitet] rührt den Betreff ohne Vorlage
  /// absichtlich nicht an, weil ein hinzugefügter Empfänger keine Ansage ist,
  /// ihn neu zu schreiben; das Abwählen ist eine. Deshalb steht es hier und
  /// nicht dort — und deshalb behält, wer selbst getippt hat, was dasteht:
  /// dieselbe Abwägung wie in `VorgangGriff._betreffNachWechsel`.
  void waehleVorlage(MailVorlage? vorlage) {
    final zurueck = vorlage == null && state.gewaehlteVorlage != null;
    final stand = zurueck && !state.textSelbstGeschrieben ? ableitung : null;
    emit(
      state.copyWith(
        gewaehlteVorlage: () => vorlage,
        entwurf: stand == null
            ? state.entwurf
            : state.entwurf.copyWith(
                betreff: stand.betreffAusVorbelegung(state.entwurf),
              ),
      ),
    );
    leiteAb(betreffAuch: true);
  }

  /// Die Zusage aus `AnredeGriff` und `VorgangGriff`: Eine ausdrückliche Wahl
  /// — Anrede, Vorlage, Vorgang — leitet auch den **Betreff** neu ab.
  void leiteAbNachWahl() => leiteAb(betreffAuch: true);

  /// Tauscht im **von Hand bearbeiteten** Text die Anredezeile und den
  /// Zusatzgruß gegen die neu gewählten (§4.7, ergänzt am 02.09.2026).
  ///
  /// Nur diese zwei, und nur wörtlich: Was die App zuletzt selbst eingesetzt
  /// hat, kennt sie und darf sie austauschen. Die Anredeart beugt Wörter mitten
  /// im Satz und die Vorlage schreibt den ganzen Text — dort wäre jede
  /// Ersetzung geraten, und darum sagt der Dialog es stattdessen
  /// (`HandarbeitHinweis`). Wie ersetzt wird, steht in [TextNachtrag].
  void _zieheNach(EntwurfAbleitung stand) {
    final nachgezogen = TextNachtrag.nachgezogen(
      state.entwurf.text,
      alteAnrede: state.anredeImText,
      neueAnrede: stand.anredeFuer(state.entwurf.alleEmpfaenger),
      alterGruss: state.zusatzgrussImText,
      neuerGruss: state.zusatzgruss,
    );
    if (nachgezogen.text == state.entwurf.text) return;
    emit(
      state.copyWith(
        entwurf: state.entwurf.copyWith(text: nachgezogen.text),
        anredeImText: nachgezogen.anrede,
        zusatzgrussImText: nachgezogen.zusatzgruss,
      ),
    );
  }

  /// Gibt den Text wieder der Ableitung zurück: Betreff und Text entstehen neu
  /// aus Vorlage, Anrede und Gruß (§4.7).
  ///
  /// Die Handarbeit ist damit weg — deshalb steht der Knopf dazu neben dem
  /// Hinweis, der sagt, was gerade nicht nachgezogen wird, und nicht bei den
  /// Chips. Ein Chip, der beim Klick den halben Text verwirft, wäre genau die
  /// Überraschung, die `textSelbstGeschrieben` verhindern soll.
  void erzeugeTextNeu() {
    if (!state.textSelbstGeschrieben) return;
    emit(state.copyWith(textSelbstGeschrieben: false));
    leiteAb(betreffAuch: true);
  }

  /// Der Füller zum aktuellen Stand. Öffentlich, weil die
  /// Platzhalter-Übersicht im Dialog dieselben Werte zeigen muss, die in den
  /// Text gehen — eine zweite Rechnung daneben liefe auseinander.
  ///
  /// **null, solange der Erzeuger fehlt** (der Dialog lädt noch). Bis zum
  /// 02.09.2026 stand hier ein `!`: Wer im Ladefenster eine Vorlage wählte,
  /// bekam den Nullfehler mitten im `build` der Übersicht.
  MailVorlagenFueller? fuellerFuer(List<String> empfaenger) =>
      ableitung?.fuellerFuer(empfaenger);

  /// Übernimmt den geänderten Entwurf und zieht den Text nach, solange der
  /// Anwalt ihn noch nicht selbst angefasst hat — mit Vorlage durch die
  /// Vorlage, ohne durch die Vorbelegung.
  ///
  /// Der **Betreff bleibt stehen**: Ein hinzugefügter Empfänger ist keine
  /// Ansage, die Betreffzeile neu zu schreiben.
  void setzeEntwurf(EmailEntwurf entwurf) {
    final stand = ableitung;
    final leitetAb = !state.textSelbstGeschrieben && stand != null;
    final angepasst = leitetAb
        ? stand.abgeleitet(entwurf, betreffAuch: false)
        : entwurf;
    emit(
      state.copyWith(
        entwurf: angepasst,
        anhangBytes: AnhangDarstellung.summe(angepasst.anhangPfade),
        // Der abgeleitete Text trägt eine **neue** Anredezeile — ein
        // hinzugefügter Empfänger macht aus „Sehr geehrter Herr Müller"
        // „Sehr geehrte Damen und Herren". Der Merker muss mit, sonst sucht
        // [_zieheNach] später nach einem Wortlaut, der nicht mehr dasteht
        // (behoben am 02.09.2026). Ohne Ableitung bleibt er, wie er ist: Dann
        // steht die alte Zeile ja noch im Text.
        anredeImText: leitetAb
            ? stand.anredeFuer(angepasst.alleEmpfaenger)
            : null,
        zusatzgrussImText: leitetAb ? state.zusatzgruss : null,
        mitleserImAn:
            anredeErzeuger?.liestJemandMit(angepasst.alleEmpfaenger) ?? false,
        anredePersoenlichMoeglich:
            anredeErzeuger?.anredePersoenlichMoeglich(
              angepasst.alleEmpfaenger,
              geschlecht: state.anredeGeschlecht,
            ) ??
            false,
        fehler: () => null,
      ),
    );
  }
}
