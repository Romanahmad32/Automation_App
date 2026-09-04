import 'dart:async';

import 'package:automation_app/core/general_widgets/rueckmeldung/laufende_rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_inhalt.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_stapel.dart';
import 'package:flutter/material.dart';

/// Hält je [OverlayState] den Stapel der sichtbaren Rückmeldungen: einen
/// `OverlayEntry`, die laufenden Meldungen mit ihren Timern, das Verdrängen der
/// ältesten und das Aufräumen.
///
/// Warum ein `OverlayEntry` und kein `ScaffoldMessenger` (04.09.2026,
/// Issue #56): Die App hat genau einen `Scaffold` (in der Shell), und alle
/// Dialoge sind nackte `AlertDialog` über `showDialog`. Eine `SnackBar` landet
/// deshalb immer **unter** der Dialogbarriere — der Anwalt sieht die Meldung
/// erst, wenn er den Dialog schließt, und oft gar nicht. Ein erst beim Zeigen
/// eingefügter Overlay-Eintrag liegt über allen Routen und überlebt sowohl den
/// Tab-Wechsel als auch das Schließen des Dialogs.
///
/// Grenze desselben Wegs: Eine Route, die **nach** der Meldung aufgeht (Dialog
/// über einer stehenden Fehlermeldung), legt sich darüber. Sie taucht wieder
/// auf, sobald die Route zu ist — die Meldung geht nicht verloren.
class RueckmeldungsSteuerung {
  RueckmeldungsSteuerung(this.overlay);

  /// Ein Stapel je Overlay, ohne dass der Aufrufer etwas halten müsste. Ein
  /// [Expando] statt einer Map, damit ein abgeräumtes Overlay samt seinem
  /// Stapel eingesammelt werden kann.
  static final Expando<RueckmeldungsSteuerung> _jeOverlay =
      Expando<RueckmeldungsSteuerung>('Rueckmeldung');

  /// Der Stapel für dieses Overlay — beim ersten Aufruf angelegt.
  static RueckmeldungsSteuerung fuer(OverlayState overlay) =>
      _jeOverlay[overlay] ??= RueckmeldungsSteuerung(overlay);

  /// Mehr als drei Meldungen übereinander liest niemand; die vierte verdrängt
  /// die älteste.
  static const int hoechstensSichtbar = 3;

  final OverlayState overlay;

  /// Älteste zuerst. Angezeigt wird umgekehrt: neueste zuoberst.
  final List<LaufendeRueckmeldung> _stapel = <LaufendeRueckmeldung>[];

  OverlayEntry? _eintrag;

  /// Die gerade sichtbaren Meldungen, älteste zuerst.
  List<LaufendeRueckmeldung> get sichtbare => List.unmodifiable(_stapel);

  /// Legt [inhalt] oben auf den Stapel — oder tauscht bei einer schon
  /// stehenden gleichen Meldung deren Inhalt gegen [inhalt] und startet den
  /// Timer neu.
  ///
  /// Ohne diese Zusammenfassung stapelte ein Bloc, der denselben Fehlerzustand
  /// zweimal ausliefert, zwei gleiche Karten übereinander; genau das war bisher
  /// von Hand wegprogrammiert (Dublettenprüfung in `PlatzhalterFehlerMelder`).
  ///
  /// Der Inhalt wird bewusst ersetzt und nicht verworfen (04.09.2026, §7.2):
  /// Meldet derselbe Vorgang zweimal denselben Fehlertext, trägt der zweite
  /// Aufruf die aktuelle Aktion (`Erneut versuchen` mit dem frischen
  /// Schnappschuss) — die des ersten Aufrufs wäre sonst stillschweigend
  /// stehen geblieben, obwohl sie auf veralteten Daten arbeitet.
  void zeige(RueckmeldungsInhalt inhalt) {
    if (!overlay.mounted) return;

    for (final laufend in _stapel) {
      if (laufend.inhalt.gleichWie(inhalt)) {
        laufend.inhalt = inhalt;
        _starteTimer(laufend, inhalt.anzeigedauer);
        _zeichneNeu();
        return;
      }
    }

    final neu = LaufendeRueckmeldung(inhalt);
    _stapel.add(neu);
    while (_stapel.length > hoechstensSichtbar) {
      _stapel.removeAt(0).brichAb();
    }
    _starteTimer(neu, inhalt.anzeigedauer);
    _zeichneNeu();
  }

  /// Nimmt eine einzelne Meldung aus dem Stapel — vom Schließen-Knopf, vom
  /// Aktionsknopf und von ihrem eigenen Timer.
  void schliesse(LaufendeRueckmeldung meldung) {
    if (!_stapel.remove(meldung)) return;
    meldung.brichAb();
    _zeichneNeu();
  }

  /// Schließt alle Meldungen dieses Overlays.
  void ausblenden() {
    if (_stapel.isEmpty) return;
    for (final laufend in _stapel) {
      laufend.brichAb();
    }
    _stapel.clear();
    _zeichneNeu();
  }

  void _starteTimer(LaufendeRueckmeldung meldung, Duration? dauer) {
    meldung.brichAb();
    if (dauer == null) return;
    meldung.timer = Timer(dauer, () => schliesse(meldung));
  }

  void _zeichneNeu() {
    if (_stapel.isEmpty) {
      _entferneEintrag();
      return;
    }
    if (!overlay.mounted) return;

    final vorhanden = _eintrag;
    if (vorhanden != null) {
      vorhanden.markNeedsBuild();
      return;
    }

    late final OverlayEntry eintrag;
    eintrag = OverlayEntry(
      // Der Bauer liest den Stapel bei jedem Aufbau frisch — deshalb genügt
      // ein einziger Eintrag für beliebig viele Meldungen.
      builder: (_) => RueckmeldungsStapel(
        meldungen: _stapel.reversed.toList(),
        beimSchliessen: schliesse,
        beimEntsorgen: () => _vergiss(eintrag),
      ),
    );
    _eintrag = eintrag;
    overlay.insert(eintrag);
  }

  void _entferneEintrag() {
    final eintrag = _eintrag;
    _eintrag = null;
    if (eintrag == null) return;
    eintrag
      ..remove()
      ..dispose();
  }

  /// Der Baum unter dem Stapel wurde weggezogen (Tab-Neuaufbau im Test, App
  /// beendet). Timer abbrechen und alles vergessen — der Eintrag selbst darf
  /// hier **nicht** angefasst werden: Sein Overlay ist gerade beim Abbauen.
  ///
  /// Der Identitätsvergleich fängt den Fall, dass zwischen Entfernen und
  /// Entsorgen längst ein neuer Eintrag steht; dessen Meldungen dürfen nicht
  /// mit abgeräumt werden.
  void _vergiss(OverlayEntry eintrag) {
    if (!identical(_eintrag, eintrag)) return;
    for (final laufend in _stapel) {
      laufend.brichAb();
    }
    _stapel.clear();
    _eintrag = null;
  }
}
