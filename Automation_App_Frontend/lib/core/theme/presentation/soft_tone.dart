import 'package:flutter/material.dart';

/// Hintergrund-/Vordergrundfarbe fuer dezente, getoente Flaechen wie Badges und
/// Info-Cards, die in **Light- und Dark-Mode** lesbar bleiben.
///
/// Das App-Theme belegt die `*Container`-Rollen (secondaryContainer,
/// tertiaryContainer) im Light-Mode bewusst mit sehr dunklen Markenfarben
/// (z. B. nahezu Schwarz). Fuer weiche Hinweisflaechen sind diese Rollen daher
/// ungeeignet — sie wirken als harte dunkle Kaesten auf weissem Grund. [SoftTone]
/// leitet stattdessen einen schwachen Tint aus einer Akzentfarbe ab.
@immutable
class SoftTone {
  final Color background;
  final Color foreground;

  const SoftTone({required this.background, required this.foreground});

  /// Erzeugt aus einer Akzentfarbe einen dezenten Ton: leicht getoenter
  /// Hintergrund ueber der Surface, die Akzentfarbe selbst als gut lesbare
  /// Schrift-/Icon-Farbe. Im Dark-Mode faellt der Tint etwas kraeftiger aus,
  /// damit die Flaeche sich vom dunklen Untergrund abhebt.
  factory SoftTone.fromAccent(Color accent, ColorScheme scheme) {
    final isLight = scheme.brightness == Brightness.light;
    final background = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.12 : 0.22),
      scheme.surface,
    );
    return SoftTone(background: background, foreground: accent);
  }

  /// Etwas kraeftigere Randfarbe zur Abgrenzung der Flaeche (z. B. fuer Badges).
  Color get border => foreground.withValues(alpha: 0.35);
}
