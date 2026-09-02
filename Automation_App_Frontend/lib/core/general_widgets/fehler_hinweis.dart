import 'package:flutter/material.dart';

/// Einzeiliger Fehlerhinweis in der Fehlerfarbe des Themes: Symbol links,
/// umbrechender Text rechts.
///
/// Erwartet den fertigen Satz, nicht nur die technische Ursache — der Anwalt
/// soll lesen, was nicht geklappt hat, und nicht eine Ausnahmemeldung deuten
/// müssen.
class FehlerHinweis extends StatelessWidget {
  const FehlerHinweis({super.key, required this.nachricht, this.inhalt});

  final String nachricht;

  /// Anklickbares oder mehrteiliges Beiwerk **unter** der Nachricht — etwa die
  /// Namen der fehlenden Pflichtfelder, die in ihr Feld springen.
  ///
  /// Nur dafür da, dass solche Meldungen dieselbe Zeile bekommen wie die
  /// einfachen (Symbol, Farbe, Abstände) statt sie nachzubauen. Ohne [inhalt]
  /// ändert sich nichts: dieselbe Zeile wie bisher.
  final Widget? inhalt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final zusatz = inhalt;

    return Row(
      // Bei mehrzeiligem Beiwerk gehört das Symbol nach oben zur Nachricht,
      // nicht auf die Mitte des ganzen Blocks.
      crossAxisAlignment: zusatz == null
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: zusatz == null
              ? Text(nachricht, style: TextStyle(color: colorScheme.error))
              : Column(
                  // Sonst zöge sich der Hinweis unter einer begrenzten Höhe
                  // (Expanded, feste Box) über die ganze Fläche.
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(nachricht, style: TextStyle(color: colorScheme.error)),
                    zusatz,
                  ],
                ),
        ),
      ],
    );
  }
}
