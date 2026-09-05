import 'package:automation_app/features/settings/presentation/widgets/ordner_auswahl_feld.dart';
import 'package:flutter/material.dart';

/// Auswahl des Vorlagenordners (#33): der Ordner, in dem die Word-Vorlagen des
/// Anwalts liegen. Leer heißt seit #103: der Unterordner `Vorlagen` unter dem
/// Ordner für die App-Daten — und ohne den weiterhin der App-Ordner des
/// Backends unter %APPDATA%, damit ein Bestand ohne jede Auswahl unverändert
/// weiterläuft.
class VorlagenOrdnerFeld extends StatelessWidget {
  const VorlagenOrdnerFeld({super.key});

  @override
  Widget build(BuildContext context) => const OrdnerAuswahlFeld(
    formControlName: 'vorlagenOrdner',
    beschriftung: 'Vorlagenordner',
    dialogTitel: 'Ordner mit den Word-Vorlagen wählen',
    hinweisOhneOrdner:
        'Ohne eigene Wahl liegen die Vorlagen unter dem Ordner für die '
        'App-Daten; fehlt auch der, verwaltet die App sie in ihrem eigenen '
        'Ordner unter AppData.',
  );
}
