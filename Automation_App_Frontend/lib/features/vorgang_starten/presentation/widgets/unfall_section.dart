import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/core/general_widgets/form/kennzeichen_field.dart';
import 'package:flutter/material.dart';

/// Karte „Unfall": Kennzeichen des Unfallgegners und Unfalltag. Nur sichtbar,
/// wenn das Rechtsgebiet „Verkehrsrecht" gewählt ist. Diese beiden Felder gehen
/// in die Referenz und (optional) in das Zentralruf-Formular ein und sind dann
/// Pflicht (Required-Validatoren setzt die View je nach Rechtsgebiet).
class UnfallSection extends StatelessWidget {
  const UnfallSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.directions_car_outlined,
      title: 'Unfall',
      children: [
        // Ohne Kandidaten: Welches Fahrzeug dem Gegner gehört, weiß die App
        // vor der Zentralruf-Antwort nicht — angeboten wird hier nichts, die
        // Schreibweise stellt das Feld beim Verlassen trotzdem selbst her.
        const KennzeichenField(
          labelText: 'Kennzeichen des Unfallgegners (z. B. HG-E 1427)',
          formControlName: 'kennzeichenGegner',
        ),
        // Direkt tippbar; das Kalender-Icon öffnet den Dialog.
        GermanDateField(
          formControlName: 'schadentag',
          labelText: 'Unfalldatum',
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          validationMessages: {
            GermanDateField.rangeError: (_) =>
                'Der Unfalltag kann nicht in der Zukunft liegen',
          },
        ),
      ],
    );
  }
}
