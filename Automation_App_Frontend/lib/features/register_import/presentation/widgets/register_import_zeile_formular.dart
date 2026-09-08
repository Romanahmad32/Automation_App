import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:flutter/material.dart';

/// Die sieben Felder, die an einer historischen Registerzeile geändert werden
/// dürfen (§6.2) — dieselben, die auch der Dienst später über
/// `RegisterHistorieAenderung` entgegennimmt.
///
/// Nicht bearbeitbar sind laufende Nummer, Aktenzeichen, Spalte 1, Freitext und
/// die Selbsteinschätzung des Erzeugers. Sie beschreiben den **Fund**, nicht
/// die Sache: Die Nummer ist der Schlüssel des Jahrgangs, und der Freitext ist
/// der Beleg, an dem sich jede Deutung nachprüfen lässt. Wer ihn überschriebe,
/// verlöre genau die Stelle, gegen die geprüft wird.
///
/// Braucht ein `ReactiveForm` über sich; die `FormGroup` spannt der Dialog auf,
/// weil sein „Änderung übernehmen" außerhalb dieses Widgets liegt.
class RegisterImportZeileFormular extends StatelessWidget {
  const RegisterImportZeileFormular({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Row(
          spacing: 12,
          children: [
            SizedBox(
              width: 140,
              child: GeneralTextField<String>(
                formControlName: 'abteilung',
                labelText: 'Abteilung',
              ),
            ),
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'rechtsgebiet',
                labelText: 'Rechtsgebiet',
              ),
            ),
          ],
        ),
        GeneralTextField<String>(
          formControlName: 'sachart',
          labelText: 'Sachart (nur bei „Bußgeldsache Name")',
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'mandant',
                labelText: 'Mandant',
              ),
            ),
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'gegner',
                labelText: 'Gegner',
              ),
            ),
          ],
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'sachbestand',
                labelText: 'Sachbestand',
              ),
            ),
            SizedBox(
              width: 180,
              child: GeneralTextField<String>(
                formControlName: 'unfalldatum',
                labelText: 'Unfalldatum',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
