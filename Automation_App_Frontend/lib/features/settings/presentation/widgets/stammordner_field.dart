import 'package:automation_app/features/settings/presentation/widgets/ordner_auswahl_feld.dart';
import 'package:flutter/material.dart';

/// Auswahl des Akten-Stammordners (§6.1, §7.1). Der eigene Name bleibt: Die
/// Sache heißt in der Kanzlei so, und `OrdnerAuswahlFeld` trägt nur die
/// Bedienung.
class StammordnerField extends StatelessWidget {
  const StammordnerField({super.key});

  @override
  Widget build(BuildContext context) => const OrdnerAuswahlFeld(
    formControlName: 'aktenStammordner',
    beschriftung: 'Stammordner des Aktensystems',
    dialogTitel: 'Stammordner des Aktensystems wählen',
    hinweisOhneOrdner:
        'Ohne Stammordner kann die App fertige Dokumente nicht '
        'automatisch in die Akte ablegen.',
  );
}
