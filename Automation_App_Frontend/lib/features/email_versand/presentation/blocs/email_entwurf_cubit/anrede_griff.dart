import 'package:automation_app/features/email_versand/domain/entities/anrede_neutral_grund.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredeart_wirkung.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/domain/services/vorlagen_pruefung.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die drei Wahlen, mit denen der Anwalt die Anrede einer Mail bestimmt
/// (§4.7, §7.1) — **Anfang**, **Anredeart** und **namentlich oder nicht**.
///
/// Eigener Baustein neben `VersandGriff`, weil die drei zusammengehören und
/// leicht verwechselt werden. Sie beantworten verschiedene Fragen:
///
/// * [waehleAnrede] — welcher Anfang („Sehr geehrter", „Guten Tag").
/// * [waehleGeschlecht] — welche **Beugung**: sie hängt am Mandanten und beugt
///   nicht nur die Anredezeile, sondern auch `{{Mandant/Mandantin}}` im
///   Vorlagentext.
/// * [setzeAnredeNeutral] — ob **namentlich** angeredet wird; das hängt am
///   Empfängerkreis, denn eine Anrede an zwei Empfänger kann nur eine sein.
///
/// Die häufigste Mail zeigt, warum die letzten zwei getrennt sind: An die
/// Versicherung geht sie mit „Sehr geehrte Damen und Herren" hinaus — nicht
/// namentlich — und schreibt im Text trotzdem von „unserer Mandantin".
mixin AnredeGriff on Cubit<EmailEntwurfState> {
  /// Der Erzeuger zum aktuellen Vorgang. Der Cubit reicht ihn herein: Ein
  /// Mixin in einer eigenen Datei sieht dessen private Felder nicht.
  EmailEntwurfErzeuger? get anredeErzeuger;

  /// Leitet Betreff und Text neu ab. Jede Wahl hier ist eine **ausdrückliche
  /// Handlung** wie die Vorlagenwahl, deshalb darf auch der Betreff neu
  /// entstehen — anders als bei einem beiläufig hinzugefügten Empfänger.
  void leiteAbNachWahl();

  /// Schreibt die Anredeart ins Mandantenregister und liefert den geänderten
  /// Mandanten; null heißt misslungen. Der Cubit erledigt es, weil danach
  /// **beides** stimmen muss: das Register und der Erzeuger, der den Mandanten
  /// hält.
  Future<Mandant?> anredeartNachtragen(Mandant mandant, Anrede anrede);

  /// Trägt die gewählte Anredeart im Mandantenregister nach (§4.7, §5.1) —
  /// **nur die Lücke, nie eine Korrektur** ([EmailEntwurfState
  /// .anredeartNachtragbar]).
  ///
  /// Der Grund für diesen Weg: Steht am Mandanten „keine Angabe", wählt der
  /// Anwalt sonst bei **jeder** Mail an ihn von Hand — die Ursache bliebe
  /// stehen. Ein Klick behebt sie an der Stelle, an der sie auffällt.
  ///
  /// Danach steht die Anredeart im Register, und die Wahl für diese Mail fällt
  /// weg: Es gibt nichts mehr zu übersteuern, und der Knopf verschwindet von
  /// selbst.
  Future<void> merkeAnredeart() async {
    final gewaehlt = state.anredeGeschlecht;
    final mandant = anredeErzeuger?.mandant;
    if (!state.anredeartNachtragbar || gewaehlt == null || mandant == null) {
      return;
    }

    final gemerkt = await anredeartNachtragen(mandant, gewaehlt);
    if (isClosed) return;
    emit(
      gemerkt == null
          // Misslingt es, bleibt die Wahl für diese Mail stehen: Der Entwurf
          // ist fertig, und ein Registerfehler darf ihn nicht anfassen.
          ? state.copyWith(
              fehler: () =>
                  'Die Anredeart liess sich im Mandantenregister nicht '
                  'hinterlegen. Für diese Mail gilt sie trotzdem.',
            )
          : state.copyWith(
              mandantAnrede: gewaehlt,
              anredeGeschlecht: () => null,
              fehler: () => null,
            ),
    );
  }

  /// Der beim Verfassen gewählte Anredeanfang (§4.7, §7.1). Die Beugung folgt
  /// der Anredeart, das Anredewort und der Nachname kommen von selbst dazu —
  /// gewählt wird nur der Anfang.
  void waehleAnrede(Anredebaustein? baustein) {
    emit(state.copyWith(anredebaustein: () => baustein));
    leiteAbNachWahl();
  }

  /// Die Anredeart dieser Mail (§4.7, ergänzt am 02.09.2026) — null gibt die
  /// Entscheidung an das Mandantenregister zurück (§5.1).
  ///
  /// Sie gilt **nur für diese Mail**: Von hier aus wird nichts in die
  /// Stammdaten geschrieben. Wer dort eine falsche Angabe findet, korrigiert
  /// sie im Register; eine Mail, die das im Vorbeigehen tut, änderte
  /// Stammdaten ohne Auftrag (§1.3). Steht dort **keine** Angabe, lässt sich
  /// die Lücke auf Klick füllen — [merkeAnredeart], und nur auf Klick.
  void waehleGeschlecht(Anrede? geschlecht) {
    emit(
      state.copyWith(
        anredeGeschlecht: () => geschlecht,
        // Muss mit: Stand am Mandanten „keine Angabe", war eine namentliche
        // Anrede unmöglich — mit der gewählten Anredeart ist sie es nicht
        // mehr, und der Umschalter „neutral" hängt daran. Ohne diese Zeile
        // bliebe „Sehr geehrte Damen und Herren" stehen, obwohl der Anwalt
        // gerade gesagt hat, wen er anschreibt.
        anredePersoenlichMoeglich:
            anredeErzeuger?.anredePersoenlichMoeglich(
              state.entwurf.alleEmpfaenger,
              geschlecht: geschlecht,
            ) ??
            state.anredePersoenlichMoeglich,
      ),
    );
    leiteAbNachWahl();
  }

  /// Übersteuert, ob neutral angeredet wird — null gibt die Entscheidung an
  /// den Empfängerkreis zurück (§4.7). Ein Hinweis, keine Sperre: Wer trotz
  /// Mitleser namentlich anreden will, darf das.
  void setzeAnredeNeutral(bool? neutral) {
    emit(state.copyWith(anredeNeutral: () => neutral));
    leiteAbNachWahl();
  }

  /// Die Zeile, die ein Anredeanfang **jetzt** ergäbe — für die Beschriftung
  /// der Chips. Über denselben Weg wie der erzeugte Text, damit auf dem Chip
  /// steht, was hinterher in der Mail steht.
  String anredeVorschau(Anredebaustein baustein) =>
      anredeErzeuger?.anredeFuer(
        state.entwurf.alleEmpfaenger,
        baustein: baustein,
        neutral: state.anredeNeutral,
        geschlecht: state.anredeGeschlecht,
      ) ??
      baustein.bezeichnung;

  /// Warum die Anrede neutral ausfällt (§4.7, ergänzt am 02.09.2026) — null
  /// heisst „namentlich" oder „so gewollt".
  ///
  /// **Gerechnet und nicht gespeichert**, aus demselben Grund wie
  /// [anredeVorschau]: über denselben Erzeuger, mit denselben Eingaben. Als
  /// Feld im Zustand liefe die Auskunft jeder Empfängeränderung hinterher —
  /// und ein Satz, der den falschen Grund nennt, ist schlechter als keiner.
  AnredeNeutralGrund? get anredeNeutralGrund => anredeErzeuger?.neutralGrund(
    state.entwurf.alleEmpfaenger,
    neutral: state.anredeNeutral,
    geschlecht: state.anredeGeschlecht,
  );

  /// Ob der Umschalter „neutral anreden" überhaupt etwas zu schalten hat —
  /// unabhängig davon, was der Empfängerkreis gerade ergibt (§4.7).
  bool get anredeNamentlichMachbar =>
      anredeErzeuger?.anredeNamentlichMachbar(
        geschlecht: state.anredeGeschlecht,
      ) ??
      false;

  /// Worauf die Anredeart **jetzt** wirkt (§4.7, ergänzt am 02.09.2026) — für
  /// den Satz über der Chipreihe, der bis dahin fest behauptete, sie beuge
  /// Anrede und Text.
  ///
  /// Die zwei Wirkungen werden getrennt festgestellt, weil sie einzeln
  /// wegfallen: Die Anredezeile braucht eine **namentliche** Anrede und eine
  /// Vorlage, die eine Stelle dafür hat; die Wörter im Text stehen in der
  /// Vorlage und werden dort gezählt, mit derselben Prüfung wie im Editor.
  AnredeartWirkung get anredeartWirkung {
    final vorlage = state.gewaehlteVorlage;
    final ohneZeile = !state.anredeMoeglich;
    return AnredeartWirkung(
      anredezeile:
          !ohneZeile &&
          anredeNeutralGrund == null &&
          state.anredeNeutral != true,
      ohneAnredezeile: ohneZeile,
      woerter: vorlage == null ? 0 : VorlagenPruefung.beugungen(vorlage).length,
    );
  }
}
