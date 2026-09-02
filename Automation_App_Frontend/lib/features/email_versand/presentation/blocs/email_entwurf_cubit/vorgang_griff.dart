import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/email_versand/domain/services/empfaenger_abgleich.dart';
import 'package:automation_app/features/email_versand/domain/services/entwurf_ableitung.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Wechsel des Vorgangs, aus dem vorbelegt wird (§4.7) — eigener Baustein
/// neben `VersandGriff` und `AnredeGriff`.
///
/// Er steht für sich, weil er der **einzige** Schritt im Dialog ist, der
/// praktisch alles neu belegt: Empfänger, Betreff, Text, Gruß, Anredeart. Und
/// weil dabei genau eine Frage zählt, die man beim Schreiben leicht verliert:
/// **Was der Anwalt selbst eingetragen hat, bleibt.** Alles, was aus dem alten
/// Vorgang stammte, geht mit ihm.
mixin VorgangGriff on Cubit<EmailEntwurfState> {
  /// Baut den Erzeuger zu einem Vorgang neu und merkt ihn. Der Cubit erledigt
  /// es: Ein Mixin in einer eigenen Datei sieht dessen private Felder nicht.
  Future<EmailEntwurfErzeuger> erzeugerFuer(
    Vorgang? vorgang, {
    Mandant? mandant,
  });

  /// Leitet Betreff und Text neu ab — der Wechsel ist eine ausdrückliche
  /// Handlung wie die Vorlagenwahl. Dieselbe Zusage wie in `AnredeGriff`; wer
  /// beide Mixins einhängt, erfüllt sie einmal.
  void leiteAbNachWahl();

  /// Die Adressen, die die **App selbst** ins Feld „An" gesetzt hat — beim
  /// Anlegen des Entwurfs und bei jedem Wechsel. Genau sie gehen beim nächsten
  /// Wechsel mit (`EmpfaengerAbgleich`).
  ///
  /// Bewusst **kein** Zustandsfeld: Auf dem Schirm steht davon nichts, gelesen
  /// wird es nur hier. Der Cubit hält es wie den Erzeuger — ein Mixin in einer
  /// eigenen Datei sieht dessen private Felder nicht.
  List<String> get vorbelegteEmpfaenger;

  set vorbelegteEmpfaenger(List<String> adressen);

  /// Wechselt den Vorgang, aus dem vorbelegt wird (§4.7) — oder nimmt
  /// **keinen**: [vorgang] null führt zum leeren Anschreiben zurück.
  ///
  /// Der Dialog geht aus dem Postfach auch dann auf, wenn sich die Antwort
  /// keinem Vorgang zuordnen liess; dort ist dieser Schalter der einzige Weg
  /// zur Vorbelegung, ohne den Dialog zu schliessen und neu zu öffnen.
  ///
  /// **Was der Anwalt selbst eingetragen hat, bleibt:** Empfänger aus den
  /// Vorschlägen des alten Vorgangs gehen mit ihm (`EmpfaengerAbgleich`),
  /// getippte Adressen und die Anhänge bleiben stehen. Betreff und Text
  /// entstehen neu — der Wechsel ist eine ausdrückliche Handlung wie die
  /// Vorlagenwahl —, es sei denn, der Anwalt hat schon selbst geschrieben
  /// ([setzeText]).
  Future<void> waehleVorgang(Vorgang? vorgang) async {
    if (state.vorgang?.referenz == vorgang?.referenz) return;

    emit(state.copyWith(wechseltVorgang: true, fehler: () => null));
    final zuvorVorbelegt = vorbelegteEmpfaenger;
    final erzeuger = await erzeugerFuer(vorgang);
    if (isClosed) return;

    // Der Gruß folgt dem Mandanten: Ein anderer Vorgang ist ein anderer
    // Adressat, und ein persönlicher Gruß, der für jemand anderen gedacht war,
    // darf den Wechsel nicht überleben (§5.1).
    final gruss = erzeuger.mandant?.persoenlicheGrussformel.trim() ?? '';
    final neueVorschlaege = [
      for (final vorschlag in erzeuger.vorschlaege) vorschlag.adresse,
    ];
    final abgeglichen = EmpfaengerAbgleich.nachWechsel(
      vorhanden: state.entwurf.an,
      zuvorVorbelegt: zuvorVorbelegt,
      neueVorschlaege: neueVorschlaege,
    );
    final empfaenger = abgeglichen.empfaenger;
    // Was jetzt vorbelegt ist, geht beim nächsten Wechsel mit — nur das, und
    // ausdrücklich nicht, was der Anwalt selbst eingetragen hat.
    vorbelegteEmpfaenger = abgeglichen.vorbelegt;

    final entwurf = state.entwurf.copyWith(
      an: empfaenger,
      // Der Betreff kommt hier und nicht aus `_leiteAb`: Ohne Vorlage
      // rührt die Ableitung ihn absichtlich nicht an, weil ein
      // hinzugefügter Empfänger keine Ansage ist, ihn neu zu schreiben.
      // Ein gewechselter Vorgang ist eine.
      betreff: _betreffNachWechsel(erzeuger),
      // Ohne Vorgang bleibt sie leer — dann wird auch nichts
      // protokolliert, genau wie beim leeren Anschreiben.
      vorgangReferenz: vorgang?.referenz ?? '',
    );

    emit(
      state.copyWith(
        entwurf: entwurf,
        vorschlaege: erzeuger.vorschlaege,
        vorgang: () => vorgang,
        zusatzgruss: gruss,
        // Wie der Gruss: Eine fuer diesen Mandanten gewaehlte Anredeart
        // darf den Wechsel nicht ueberleben — sonst redet die naechste Mail
        // jemand anderen in der Beugung des Vorgaengers an (§5.1).
        anredeGeschlecht: () => null,
        // Und aus demselben Grund die Entscheidung „neutral anreden": Sie
        // galt fuer **diesen** Empfaengerkreis. Blieb sie stehen, wurde der
        // naechste Mandant namentlich angeredet, obwohl die Mail an die
        // Versicherung ging (behoben am 02.09.2026). null heisst wieder
        // „wie der Empfaengerkreis es ergibt".
        anredeNeutral: () => null,
        mandantAnrede: erzeuger.mandant?.anrede ?? Anrede.keine,
        mandantBekannt: erzeuger.mandant != null,
        // Beide über `alleEmpfaenger` und nicht über die `an`-Liste: Wer in
        // **Kopie** steht, liest genauso mit, und `EntwurfAbleitung.anredeFuer`
        // rechnet ebenso. Mit der kurzen Liste widersprachen die Flags der
        // Anredezeile im Text (behoben am 02.09.2026). Die Anredeart ist
        // gerade zurückgesetzt, also gilt wieder die des Mandanten.
        mitleserImAn: erzeuger.liestJemandMit(entwurf.alleEmpfaenger),
        anredePersoenlichMoeglich: erzeuger.anredePersoenlichMoeglich(
          entwurf.alleEmpfaenger,
        ),
        wechseltVorgang: false,
      ),
    );
    leiteAbNachWahl();
  }

  /// Der Betreff nach einem Vorgangswechsel — nur für den Fall **ohne**
  /// Vorlage. Mit Vorlage schreibt ihn `_leiteAb` gleich danach aus den
  /// Platzhaltern, und wer selbst getippt hat, behält, was dasteht.
  String _betreffNachWechsel(EmailEntwurfErzeuger erzeuger) {
    if (state.gewaehlteVorlage != null || state.textSelbstGeschrieben) {
      return state.entwurf.betreff;
    }
    return EntwurfAbleitung(
      erzeuger: erzeuger,
    ).betreffAusVorbelegung(state.entwurf);
  }
}
