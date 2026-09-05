import 'package:automation_app/features/form_template_setup/domain/services/feld_vorkommen.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_vorkommen_beobachter.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_vorkommen_pille.dart';
import 'package:flutter/material.dart';

/// Kennzeichen an einer Feldzeile — **nur noch** die Warnung „in keiner
/// Datei" (#35 Teil 3, Gestalt aus #104).
///
/// Vorher zeigte es alle vier Fälle: *beide · nur HGN · nur Auflistung · in
/// keiner Datei*. Drei davon waren reine Auskunft und standen an **jeder**
/// Zeile — achtzehn Kennzeichen, die sagen, dass alles in Ordnung ist,
/// verstecken das eine, das es nicht ist. Die drei Fälle sind deshalb weg;
/// wer wissen will, welche Datei welches Feld einsetzt, sieht das am
/// Platzhalter-Bestand der Dateikarten.
///
/// Was bleibt, ist der Befund, der etwas kostet: Ein Feld, dessen Name in
/// keiner Word-Datei vorkommt, bleibt beim Erzeugen wirkungslos. Es ist
/// zugleich der Weg zur Reparatur — ein Klick öffnet die Zuordnung (#36).
class FeldVorkommenBadge extends StatelessWidget {
  final String formControlName;

  /// Wird beim Klick gerufen. Null lässt das Kennzeichen stumm — etwa dort,
  /// wo es keine Platzhalterliste zum Wählen gibt.
  final VoidCallback? onZuordnen;

  const FeldVorkommenBadge({
    super.key,
    required this.formControlName,
    this.onZuordnen,
  });

  @override
  Widget build(BuildContext context) {
    return FeldVorkommenBeobachter(
      formControlName: formControlName,
      builder: (context, vorkommen) => vorkommen == FeldVorkommen.inKeinerDatei
          ? FeldVorkommenPille(vorkommen: vorkommen!, onZuordnen: onZuordnen)
          : const SizedBox.shrink(),
    );
  }
}
