import 'package:flutter/material.dart';

/// Einer der drei benannten Abschnitte des Versandformulars — „Empfänger",
/// „Inhalt", „Anhänge" (§4.7).
///
/// **Der Mangel, den das behebt:** Das Formular war eine Reihe von rund fünfzehn
/// Blöcken, getrennt nur durch `SizedBox(height: 16)`. Empfängerzeilen, Anrede,
/// Betreff, Signaturbilder und Größenbalken standen ununterscheidbar
/// untereinander, und wo man gerade ist, war ohne Scrollen nicht zu sagen.
///
/// Keine Karten: Der Dialog ist selbst schon eine Fläche, und Karten darin
/// würden sie ein zweites Mal rahmen. Eine Überschrift mit Zeichen und eine
/// feine Linie darunter reichen, um drei Gruppen zu drei Gruppen zu machen.
class VersandAbschnitt extends StatelessWidget {
  final IconData symbol;
  final String titel;

  /// Was der Abschnitt beantwortet, in einem halben Satz; null lässt ihn weg.
  final String? untertitel;

  final List<Widget> children;

  const VersandAbschnitt({
    super.key,
    required this.symbol,
    required this.titel,
    this.untertitel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(symbol, size: 18, color: theme.colorScheme.primary),
              Text(
                titel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            ],
          ),
          if (untertitel != null) ...[
            const SizedBox(height: 4),
            Text(
              untertitel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
