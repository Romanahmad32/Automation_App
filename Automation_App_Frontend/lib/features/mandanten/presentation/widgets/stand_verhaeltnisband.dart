import 'package:flutter/material.dart';

/// Dünnes Verhältnisband unter dem Zählerband der Stand-Karte: zeigt auf
/// einen Blick, wie [gesamt] sich auf zugeordnet, ohne Bezug und offen
/// verteilt — ohne den Anwalt zu einer eigenen Interpretation der vier Zahlen
/// zu zwingen.
///
/// „Offen" bekommt bewusst keine eigene Fläche: es ist der unbedeckte Rest des
/// getönten Untergrunds. Zwei Farben genügen, weil die dritte immer der
/// Hintergrund selbst ist.
class StandVerhaeltnisband extends StatelessWidget {
  final int gesamt;
  final int zugeordnet;
  final int ohneBezug;

  static const double hoehe = 7;

  const StandVerhaeltnisband({
    super.key,
    required this.gesamt,
    required this.zugeordnet,
    required this.ohneBezug,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final zugeordnetAnteil = gesamt > 0 ? zugeordnet / gesamt : 0.0;
    final ohneBezugAnteil = gesamt > 0 ? ohneBezug / gesamt : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(hoehe / 2),
      child: SizedBox(
        height: hoehe,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final breite = constraints.maxWidth;
            return Stack(
              children: [
                ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: SizedBox(width: breite, height: hoehe),
                ),
                Container(
                  width: breite * zugeordnetAnteil,
                  height: hoehe,
                  color: scheme.primary,
                ),
                Positioned(
                  left: breite * zugeordnetAnteil,
                  child: Container(
                    width: breite * ohneBezugAnteil,
                    height: hoehe,
                    color: scheme.outline,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
