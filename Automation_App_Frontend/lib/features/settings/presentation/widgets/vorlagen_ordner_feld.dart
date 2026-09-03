import 'package:automation_app/features/settings/presentation/widgets/ordner_auswahl_feld.dart';
import 'package:flutter/material.dart';

/// Auswahl des Vorlagenordners (#33): der Ordner, in dem die Word-Vorlagen des
/// Anwalts liegen. Leer heißt App-Ordner des Backends unter %APPDATA% — der
/// Stand vor dieser Einstellung, damit ein Bestand ohne Auswahl unverändert
/// weiterläuft.
class VorlagenOrdnerFeld extends StatelessWidget {
  const VorlagenOrdnerFeld({super.key});

  @override
  Widget build(BuildContext context) => const OrdnerAuswahlFeld(
    formControlName: 'vorlagenOrdner',
    beschriftung: 'Vorlagenordner',
    dialogTitel: 'Ordner mit den Word-Vorlagen wählen',
    hinweisOhneOrdner:
        'Ohne Auswahl verwaltet die App die Vorlagen in ihrem eigenen '
        'Ordner unter AppData. Ein selbst gewählter Ordner wird '
        'mitgesichert und macht die Sicherung auf einem zweiten '
        'Rechner vollständig.',
  );
}
