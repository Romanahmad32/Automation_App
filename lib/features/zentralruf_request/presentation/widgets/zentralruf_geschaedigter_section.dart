import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/zentralruf_request/presentation/widgets/zentralruf_form_validators.dart';
import 'package:flutter/material.dart';

/// Optionaler Abschnitt „Geschädigter": per Schalter aktivierbar, kann aus dem
/// Mandantenregister vorbefüllt werden. Auswahl/Schalter meldet das Widget über
/// Callbacks zurück; die Textfelder laufen über Reactive-Forms-Controls.
class ZentralrufGeschaedigterSection extends StatelessWidget {
  final bool withGeschaedigter;
  final List<Mandant> mandanten;
  final int? selectedMandantId;
  final ValueChanged<bool> onToggle;
  final ValueChanged<Mandant> onMandantGewaehlt;

  const ZentralrufGeschaedigterSection({
    super.key,
    required this.withGeschaedigter,
    required this.mandanten,
    required this.selectedMandantId,
    required this.onToggle,
    required this.onMandantGewaehlt,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.person_outline,
      title: 'Geschädigter',
      subtitle:
          'Optional — nur ausfüllen, wenn die Daten dem '
          'Zentralruf-Formular mitgegeben werden sollen.',
      trailing: Switch(value: withGeschaedigter, onChanged: onToggle),
      children: [
        if (withGeschaedigter) ...[
          if (mandanten.isNotEmpty)
            SearchableDropdown<int>(
              value: selectedMandantId,
              labelText: 'Aus Mandanten übernehmen',
              hintText: 'Mandant suchen oder auswählen',
              helperText:
                  'Füllt die Felder aus dem Register; '
                  'Änderungen am Namen lösen die Verknüpfung.',
              helperMaxLines: 2,
              entries: [
                for (final mandant in mandanten)
                  SearchableDropdownEntry(
                    value: mandant.id,
                    label: mandant.anzeigename,
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                onMandantGewaehlt(mandanten.firstWhere((m) => m.id == id));
              },
            ),
          const GeneralTextField<String>(
            labelText: 'Name des Geschädigten',
            formControlName: 'geschaedigterName',
          ),
          const GeneralTextField<String>(
            labelText: 'Straße und Hausnummer',
            formControlName: 'geschaedigterStrasseHausnummer',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                flex: 2,
                child: GeneralTextField<String>(
                  labelText: 'PLZ',
                  formControlName: 'geschaedigterPostleitzahl',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: GeneralTextField<String>(
                  labelText: 'Ort',
                  formControlName: 'geschaedigterOrt',
                ),
              ),
            ],
          ),
          GeneralTextField<String>(
            labelText: 'Kennzeichen des Geschädigten (z. B. HG-E 1427)',
            formControlName: 'geschaedigterKennzeichen',
            validationMessages: kennzeichenMessages,
          ),
        ],
      ],
    );
  }
}
