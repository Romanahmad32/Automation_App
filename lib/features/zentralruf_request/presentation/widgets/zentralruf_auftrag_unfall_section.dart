import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/zentralruf_request/presentation/widgets/zentralruf_form_validators.dart';
import 'package:flutter/material.dart';

/// Die Karten „Auftrag" und „Unfall" nebeneinander (gleiche Höhe), oben im
/// Anfrageformular. Felder über Reactive-Forms-Controls; das Rechtsgebiet ist
/// lokaler State der View und kommt über [rechtsgebiet]/[onRechtsgebietChanged].
class ZentralrufAuftragUnfallSection extends StatelessWidget {
  final Rechtsgebiet rechtsgebiet;
  final ValueChanged<Rechtsgebiet> onRechtsgebietChanged;

  const ZentralrufAuftragUnfallSection({
    super.key,
    required this.rechtsgebiet,
    required this.onRechtsgebietChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FormSection(
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
                  ],
                ),
                const GeneralTextField<String>(
                  labelText: 'Abteilung (z. B. C03)',
                  formControlName: 'abteilung',
                ),
                SearchableDropdown<Rechtsgebiet>(
                  value: rechtsgebiet,
                  labelText: 'Rechtsgebiet',
                  hintText: 'Rechtsgebiet suchen oder auswählen',
                  entries: [
                    for (final gebiet in Rechtsgebiet.values)
                      SearchableDropdownEntry(
                        value: gebiet,
                        label: gebiet.displayName,
                      ),
                  ],
                  onChanged: (gebiet) => onRechtsgebietChanged(
                    gebiet ?? Rechtsgebiet.verkehrsrecht,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FormSection(
              icon: Icons.directions_car_outlined,
              title: 'Unfall',
              children: [
                GeneralTextField<String>(
                  labelText:
                      'Kennzeichen des Unfallgegners (z. B. HG-E 1427)',
                  formControlName: 'kennzeichenSchaediger',
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
            ),
          ),
        ],
      ),
    );
  }
}
