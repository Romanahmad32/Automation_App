import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
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
        GeneralTextField<String>(
          labelText: 'Kennzeichen des Unfallgegners (z. B. HG-E 1427)',
          formControlName: 'kennzeichenGegner',
          validationMessages: kennzeichenMessages,
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
