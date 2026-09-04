import 'package:flutter/material.dart';

/// Die drei Arten flüchtiger Rückmeldung und ihr **unterschiedliches
/// Verhalten** — Standarddauer, Symbol und Akzentfarbe hängen an der Art, nicht
/// an der Aufrufstelle.
///
/// Warum je Art eine andere Dauer (04.09.2026, Issue #56): „Gespeichert" ist
/// gelesen, bevor der Blick zurück ins Formular geht — drei Sekunden reichen.
/// Ein Fehler dagegen sagt, was zu tun ist („Bitte schließen Sie das
/// Dokument …"); in drei Sekunden liest die niemand zu Ende. Deshalb hat
/// [fehler] **keine** Dauer: die Meldung bleibt stehen, bis der Anwalt sie
/// schließt.
///
/// Warum zusätzlich ein Symbol je Art: Farbe allein trägt die Unterscheidung
/// nicht — nicht bei Rot-Grün-Schwäche und nicht auf einem blassen Bildschirm.
enum RueckmeldungsArt {
  erfolg(standardDauer: Duration(seconds: 3), icon: Icons.check_circle_outline),
  hinweis(standardDauer: Duration(seconds: 5), icon: Icons.info_outline),
  fehler(standardDauer: null, icon: Icons.error_outline);

  const RueckmeldungsArt({required this.standardDauer, required this.icon});

  /// Wie lange die Meldung von selbst stehen bleibt. `null` heißt: gar nicht
  /// von selbst verschwinden, sondern auf den Schließen-Knopf warten.
  final Duration? standardDauer;

  /// Symbol links in der Karte.
  final IconData icon;

  /// Untergrenze, sobald eine `RueckmeldungsAktion` angeboten wird: Wer noch
  /// „Erneut versuchen" drücken soll, braucht länger als drei Sekunden, um die
  /// Meldung zu lesen, die Maus zu greifen und zu treffen.
  static const Duration mitAktionMindestens = Duration(seconds: 8);

  /// Farbe, aus der die Karte ihren dezenten Ton zieht (`SoftTone.fromAccent`).
  ///
  /// Fehler und Hinweis nehmen Rollen des Themes. **Erfolg nicht**: Das
  /// Farbschema kennt keine Erfolgsrolle (Stand 04.09.2026 — `ColorScheme` hat
  /// error/primary/secondary/tertiary, aber kein Grün mit dieser Bedeutung),
  /// und `primary` wäre hier nicht unterscheidbar vom Hinweis. Deshalb zwei
  /// feste Grüntöne — im Light-Mode dunkel genug zum Lesen, im Dark-Mode hell
  /// genug, um sich abzuheben.
  Color akzent(ColorScheme schema) => switch (this) {
    RueckmeldungsArt.fehler => schema.error,
    RueckmeldungsArt.hinweis => schema.primary,
    RueckmeldungsArt.erfolg =>
      schema.brightness == Brightness.light
          ? const Color(0xFF2E7D32)
          : const Color(0xFF81C784),
  };
}
