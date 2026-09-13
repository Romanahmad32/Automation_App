import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:flutter/foundation.dart' show mapEquals;

/// Legt den angefangenen Ausfüllstand am Vorgang ab — und räumt ihn dort weg,
/// sobald nichts mehr von der Vorbelegung abweicht.
///
/// Steht neben dem `WizardCubit` statt in ihm, weil hier eigener veränderlicher
/// Zustand liegt, der nichts mit dem Wizard-Zustand zu tun hat: die Marke
/// „schon bestätigt". Sie ist Buchführung über die *Ablage*, nicht über das,
/// was der Anwalt sieht — und lässt sich so einzeln prüfen, ohne einen Cubit
/// aufzubauen.
///
/// **Kein eigener Takt mehr** (#133): Früher sammelte hier ein Zeitgeber zwei
/// Sekunden lang, bevor etwas hinausging. Das war eine zweite Entprellung hinter
/// der des `FormWertBeobachter` — zusammen bis zu vier Sekunden, in denen der
/// Stand nur im Speicher lag. Seit der Beobachter nach 300 ms meldet, ist seine
/// Meldung selbst der Auslöser: Wer hier ankommt, wird abgelegt.
///
/// Die Ablage läuft über den app-weiten [VorgangCubit] statt über das
/// Repository direkt: Sonst hielte dessen Liste weiter den Vorgang **ohne** den
/// gerade gesicherten Stand, und der nächste Einstieg zeigte einen veralteten.
class EntwurfsSicherung {
  final VorgangCubit _vorgaenge;

  /// Ob der aktuelle Stand bereits **bestätigt** ist (ein Dokument daraus
  /// erzeugt). Dann wird nichts mehr abgelegt: Der Rückfluss hat den Entwurf im
  /// selben Atemzug am Vorgang gelöscht, und eine Sicherung danach brächte ihn
  /// zurück — das Formular zeigte beim nächsten Einstieg einen Stand, der längst
  /// in einem Schreiben steht. Jede weitere Eingabe hebt die Marke wieder auf
  /// ([hebeBestaetigungAuf]).
  bool _bestaetigt = false;

  /// Zu welcher Vorgangsreferenz die beiden Felder darunter etwas sagen. Ohne
  /// Treffer (referenzverschieden oder noch nichts gesendet) gilt die Merkung
  /// als leer — ein Vorgangswechsel darf sich nie an einem zufällig gleichen
  /// Stand des vorigen Vorgangs vorbeischummeln (Mangel 1, #133).
  String? _letzteReferenz;

  /// Ob für [_letzteReferenz] schon einmal tatsächlich geschrieben wurde —
  /// erst dann sagen [_letzteFeldWerte]/[_letzteAufstellung] etwas.
  bool _hatGeschrieben = false;

  /// Feldwerte des zuletzt erfolgreich abgesetzten Entwurfs (leer bei einer
  /// Löschung).
  Map<String, String> _letzteFeldWerte = const {};

  /// Schadensaufstellung des zuletzt erfolgreich abgesetzten Entwurfs.
  DamageListing? _letzteAufstellung;

  EntwurfsSicherung(this._vorgaenge);

  void markiereBestaetigt() => _bestaetigt = true;

  /// Eine neue Eingabe macht aus dem bestätigten Stand wieder einen
  /// angefangenen.
  void hebeBestaetigungAuf() => _bestaetigt = false;

  /// Legt den Stand ab — aber nur, wenn er sich von dem unterscheidet, was
  /// zuletzt tatsächlich hinausging (Mangel 1, #133): Jede Meldung des
  /// `FormWertBeobachter` rief bisher ungeprüft hierher, auch das bloße
  /// Nachmelden beim Verlassen ohne neue Eingabe — ein PUT am Dienst pro
  /// Meldung statt pro Änderung. Verglichen wird **ohne** [VorgangEntwurf.gespeichertAm]:
  /// Das Objekt selbst wäre nie gleich, weil der Zeitstempel jedes Mal neu ist.
  ///
  /// Ohne [referenz] fehlt der Ablageort — freie Erfassung hält keinen Entwurf
  /// (bewusste Abgrenzung des ersten Wurfs). `werte == null` heißt „noch
  /// nichts gemeldet", nicht „nichts mehr da": Dann wurde in diesem Durchgang
  /// nie getippt, und ein Löschen träfe einen Stand, den der Anwalt gar nicht
  /// angerührt hat.
  ///
  /// [werte] enthält **nur die Abweichungen** von der Vorbelegung
  /// (`EntwurfAbweichung.nurAbweichende`). Bleibt davon nichts übrig und liegen
  /// auch keine Schadenspositionen vor, wird der Entwurf am Vorgang **gelöscht**
  /// statt leer geschrieben: Ein leerer Stand wäre ein Versprechen ohne Inhalt,
  /// und der nächste Einstieg müsste ihn erst wieder wegrechnen. Ausnahme: Vor
  /// dem ersten eigenen Schreiben zu dieser Referenz **und** ohne Entwurf am
  /// Vorgang gibt es nichts zu löschen — dann bleibt die Ablage unberührt
  /// (Befund 2 der Review-Nachbesserung zu #133).
  void jetzt({
    required String? referenz,
    required Map<String, String>? werte,
    required DamageListing? aufstellung,
  }) {
    if (referenz == null || werte == null || _bestaetigt) return;

    // Ein anderer Vorgang als beim letzten Schreiben: Die Merkung gehörte zu
    // ihm, nicht zu diesem — sonst spart sich ein zufällig gleicher Stand
    // seinen eigenen Schreibaufruf.
    if (_letzteReferenz == null ||
        !Vorgang.gleicheReferenz(_letzteReferenz!, referenz)) {
      _letzteReferenz = referenz;
      _hatGeschrieben = false;
    }

    // „Keine Aufstellung" und „eine Aufstellung ohne Positionen" sind dasselbe:
    // Beide erzeugen im Schreiben keine Tabelle, und die Gebührensätze daneben
    // sind ohne Position ohne Wirkung.
    final positionen = (aufstellung?.items.isEmpty ?? true)
        ? null
        : aufstellung;
    final nichtsMehrDa = werte.isEmpty && positionen == null;

    // Vor dem ersten eigenen Schreiben ist „nichts weicht ab" kein
    // Löschauftrag, solange auch am Vorgang kein Entwurf liegt: Ein nie
    // angerührtes Formular verlassen darf kein DELETE ins Leere auslösen
    // (Review-Nachbesserung #133, Befund 2).
    if (!_hatGeschrieben &&
        nichtsMehrDa &&
        _vorgaenge.findeZuReferenz(referenz)?.entwurf == null) {
      return;
    }

    if (_hatGeschrieben &&
        mapEquals(werte, _letzteFeldWerte) &&
        positionen == _letzteAufstellung) {
      return;
    }
    _hatGeschrieben = true;
    _letzteFeldWerte = werte;
    _letzteAufstellung = positionen;

    if (nichtsMehrDa) {
      _vorgaenge.sichereEntwurf(referenz, null);
      return;
    }
    _vorgaenge.sichereEntwurf(
      referenz,
      VorgangEntwurf(
        gespeichertAm: DateTime.now(),
        feldWerte: werte,
        schadensaufstellung: positionen,
      ),
    );
  }
}
