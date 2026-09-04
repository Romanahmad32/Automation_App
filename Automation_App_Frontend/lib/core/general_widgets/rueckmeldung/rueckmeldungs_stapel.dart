import 'package:automation_app/core/general_widgets/rueckmeldung/laufende_rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_karte.dart';
import 'package:flutter/material.dart';

/// Der Stapel aller gerade sichtbaren Rückmeldungen — **oben rechts** im
/// Fenster, neueste zuoberst, ältere rücken nach unten.
///
/// Warum oben rechts (04.09.2026, Issue #56): Der Stapel liegt in einem
/// `OverlayEntry`, also über allem. Unten stehen in dieser App die Knöpfe
/// („Speichern", „Weiter", die Assistentenleiste) — eine Meldung dort verdeckt
/// genau das, was der Anwalt als Nächstes drücken will. Der obere Rand ist frei,
/// sobald man unter der `SeitenAppBar` bleibt: deren 76 px plus Luft ergeben
/// [obenAbstand], damit der Aktualisieren-Knopf rechts oben erreichbar bleibt.
///
/// Warum [Positioned] statt einer bildschirmfüllenden Fläche: Alles außerhalb
/// der Karten muss klickbar bleiben — eine stehende Fehlermeldung darf die App
/// nicht lahmlegen.
class RueckmeldungsStapel extends StatefulWidget {
  const RueckmeldungsStapel({
    super.key,
    required this.meldungen,
    required this.beimSchliessen,
    this.beimEntsorgen,
  });

  /// Neueste zuerst — in dieser Reihenfolge stehen sie auch untereinander.
  final List<LaufendeRueckmeldung> meldungen;

  final void Function(LaufendeRueckmeldung meldung) beimSchliessen;

  /// Aufgerufen, wenn der Stapel aus dem Baum fällt — auch dann, wenn nicht er
  /// selbst das ausgelöst hat, sondern ein neuer Baum unter ihm weggezogen
  /// wurde. Die Steuerung bricht darauf ihre Timer ab; sonst stünde in einem
  /// Widget-Test nach dem Ende des Tests noch ein Timer aus.
  final VoidCallback? beimEntsorgen;

  /// Abstand zum oberen Fensterrand: unterhalb der 76 px hohen `SeitenAppBar`.
  static const double obenAbstand = 88;

  /// Abstand zum rechten Fensterrand.
  static const double randAbstand = 16;

  /// Breite einer Karte. Im schmalen Fenster bleibt weniger übrig; unter
  /// [mindestBreite] soll sie nicht fallen, über [hoechstBreite] nicht wachsen.
  static const double breite = 400;
  static const double mindestBreite = 280;
  static const double hoechstBreite = 440;

  @override
  State<RueckmeldungsStapel> createState() => _RueckmeldungsStapelState();
}

class _RueckmeldungsStapelState extends State<RueckmeldungsStapel> {
  @override
  void dispose() {
    widget.beimEntsorgen?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: RueckmeldungsStapel.obenAbstand,
      left: RueckmeldungsStapel.randAbstand,
      right: RueckmeldungsStapel.randAbstand,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topRight,
          // Ohne heightFactor griffe Align in der senkrecht unbegrenzten
          // Positioned-Zeile nach unendlicher Höhe.
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: RueckmeldungsStapel.mindestBreite,
              maxWidth: RueckmeldungsStapel.hoechstBreite,
            ),
            child: SizedBox(
              width: RueckmeldungsStapel.breite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  for (final meldung in widget.meldungen)
                    RueckmeldungsKarte(
                      key: meldung.schluessel,
                      inhalt: meldung.inhalt,
                      beimSchliessen: () => widget.beimSchliessen(meldung),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
