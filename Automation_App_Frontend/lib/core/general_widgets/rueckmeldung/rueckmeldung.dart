import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_aktion.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_art.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_inhalt.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_steuerung.dart';
import 'package:flutter/material.dart';

export 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_aktion.dart';
export 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_art.dart';

/// **Der** Weg, dem Anwalt eine flüchtige Meldung zu zeigen — Erfolg, Hinweis,
/// Fehler. Kein `ScaffoldMessenger`, keine `SnackBar` (04.09.2026, Issue #56).
///
/// Warum nicht `ScaffoldMessenger`: Die App hat genau einen `Scaffold` (in der
/// Shell), und alle Dialoge sind nackte `AlertDialog` über `showDialog` ohne
/// eigenen Messenger. Eine `SnackBar` landet damit **unter** der
/// Dialogbarriere — sie erscheint zwar, aber verdeckt und unklickbar, und ist
/// wieder weg, bevor der Dialog zu ist. Sie legt sich außerdem unten über die
/// Schaltflächen, also über das, was als Nächstes gedrückt werden soll.
/// [Rueckmeldung] schreibt stattdessen in das Wurzel-Overlay: oben rechts, über
/// allen Routen, mehrere Meldungen untereinander, jede mit eigenem
/// Schließen-Knopf.
///
/// **Als Handle fassen, bevor ein `await` dazwischenliegt** — genau dort, wo
/// bisher `final messenger = ScaffoldMessenger.of(context)` stand:
///
/// ```dart
/// final rueckmeldung = Rueckmeldung.von(context);
/// final ergebnis = await _speichere();
/// rueckmeldung.erfolg('Kanzleidaten gespeichert.');
/// ```
///
/// Liegt kein `await` dazwischen, tun es die Kurzformen:
/// `Rueckmeldung.zeigeFehler(context, 'Speichern fehlgeschlagen.')`.
class Rueckmeldung {
  /// Fasst das Wurzel-Overlay über [context]. Der Handle überlebt danach jedes
  /// `await`, weil er den `BuildContext` nicht mehr braucht.
  Rueckmeldung.von(BuildContext context)
    : _steuerung = RueckmeldungsSteuerung.fuer(
        Overlay.of(context, rootOverlay: true),
      );

  final RueckmeldungsSteuerung _steuerung;

  /// „Gespeichert", „Versendet" — verschwindet nach drei Sekunden von selbst.
  void erfolg(String text, {RueckmeldungsAktion? aktion}) =>
      _zeige(RueckmeldungsArt.erfolg, text, aktion: aktion);

  /// Etwas ist anders gelaufen als erwartet, aber nichts ist schiefgegangen —
  /// fünf Sekunden, mit [dauer] auch länger.
  void hinweis(String text, {RueckmeldungsAktion? aktion, Duration? dauer}) =>
      _zeige(RueckmeldungsArt.hinweis, text, aktion: aktion, dauer: dauer);

  /// Bleibt stehen, bis der Anwalt sie schließt: Eine Fehlermeldung sagt, was
  /// zu tun ist — in drei Sekunden liest die niemand zu Ende.
  void fehler(String text, {RueckmeldungsAktion? aktion}) =>
      _zeige(RueckmeldungsArt.fehler, text, aktion: aktion);

  /// Schließt alle sichtbaren Meldungen; steht keine, passiert nichts.
  void ausblenden() => _steuerung.ausblenden();

  void _zeige(
    RueckmeldungsArt art,
    String text, {
    RueckmeldungsAktion? aktion,
    Duration? dauer,
  }) => _steuerung.zeige(
    RueckmeldungsInhalt(text: text, art: art, aktion: aktion, dauer: dauer),
  );

  /// Kurzform von [erfolg] für den häufigsten Fall: kein `await` zwischen
  /// [context] und der Meldung.
  static void zeigeErfolg(
    BuildContext context,
    String text, {
    RueckmeldungsAktion? aktion,
  }) => Rueckmeldung.von(context).erfolg(text, aktion: aktion);

  /// Kurzform von [hinweis].
  static void zeigeHinweis(
    BuildContext context,
    String text, {
    RueckmeldungsAktion? aktion,
    Duration? dauer,
  }) => Rueckmeldung.von(context).hinweis(text, aktion: aktion, dauer: dauer);

  /// Kurzform von [fehler].
  static void zeigeFehler(
    BuildContext context,
    String text, {
    RueckmeldungsAktion? aktion,
  }) => Rueckmeldung.von(context).fehler(text, aktion: aktion);
}
