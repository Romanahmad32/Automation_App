import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:flutter/material.dart';

/// Karte „Auftrag" oben im Formular: laufende Auftragsnummer, Jahr, Abteilung
/// und Rechtsgebiet. Das Rechtsgebiet ist lokaler State der View und steuert,
/// ob die Unfall-Abschnitte sichtbar werden (kommt über [rechtsgebiet]/
/// [onRechtsgebietChanged]).
class AuftragSection extends StatelessWidget {
  final Rechtsgebiet rechtsgebiet;
  final ValueChanged<Rechtsgebiet> onRechtsgebietChanged;

  const AuftragSection({
    super.key,
    required this.rechtsgebiet,
    required this.onRechtsgebietChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.assignment_outlined,
      title: 'Auftrag',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              flex: 3,
              child: GeneralTextField<String>(
                labelText: 'Auftragsnummer',
                formControlName: 'auftragsnummer',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GeneralTextField<String>(
                labelText: 'Jahr',
                formControlName: 'auftragsjahr',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: GeneralTextField<String>(
                labelText: 'Abteilung (z. B. C03)',
                formControlName: 'abteilung',
              ),
            ),
          ],
        ),
        SearchableDropdown<Rechtsgebiet>(
          value: rechtsgebiet,
          labelText: 'Rechtsgebiet',
          hintText: 'Rechtsgebiet suchen oder auswählen',
          helperText:
              'Bei „Verkehrsrecht" werden Unfall- und Zentralruf-Felder '
              'eingeblendet.',
          helperMaxLines: 2,
          entries: [
            for (final gebiet in Rechtsgebiet.values)
              SearchableDropdownEntry(
                value: gebiet,
                label: gebiet.displayName,
              ),
          ],
          onChanged: (gebiet) =>
              onRechtsgebietChanged(gebiet ?? Rechtsgebiet.verkehrsrecht),
        ),
      ],
    );
  }
}
