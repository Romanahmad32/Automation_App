import 'package:flutter/material.dart';

/// Einzeiliger Fehlerhinweis in der Fehlerfarbe des Themes: Symbol links,
/// umbrechender Text rechts.
///
/// Erwartet den fertigen Satz, nicht nur die technische Ursache — der Anwalt
/// soll lesen, was nicht geklappt hat, und nicht eine Ausnahmemeldung deuten
/// müssen.
class FehlerHinweis extends StatelessWidget {
  const FehlerHinweis({super.key, required this.nachricht});

  final String nachricht;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.error_outline, color: colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(nachricht, style: TextStyle(color: colorScheme.error)),
        ),
      ],
    );
  }
}
