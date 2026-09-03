import 'package:flutter/material.dart';

/// Die Zeile über dem Speichern-Knopf der Mandanten-Karte, solange die
/// Mandantendaten nur im Formular stehen und nicht im Register.
///
/// Der Schritt, dessen Vergessen als einziger Datenverlust bedeutet, hatte
/// bisher die zurückhaltendste Anzeige der Seite: Der Knopf am Kartenende wurde
/// lediglich *aktiv* — eine Zustandsänderung, die nur sieht, wer ohnehin
/// hinschaut. Der Hinweis sagt stattdessen aus, was offen ist (§1.3: erfasste
/// Daten gehen nicht verloren).
///
/// Rechtsbündig wie der Knopf darunter: Beide gehören zusammen, der Satz nennt
/// den offenen Punkt und der Knopf erledigt ihn.
class MandantUngespeichertHinweis extends StatelessWidget {
  const MandantUngespeichertHinweis({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Der gefüllte Punkt ist die übliche Marke für „noch nicht
        // gespeichert"; klein genug, um neben dem Satz nicht zu lärmen.
        Icon(
          Icons.fiber_manual_record,
          size: 12,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Ungespeicherte Änderungen am Mandanten',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
