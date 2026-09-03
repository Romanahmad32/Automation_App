import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/abteilung_auswahl.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/sachgebiet_katalog_builder.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:flutter/material.dart';

/// Karte „Auftrag" oben im Formular: laufende Auftragsnummer, Jahr, Abteilung
/// und Rechtsgebiet. Beide Auswahlen kommen aus dem Sachgebietskatalog (§7.1):
/// die Abteilung als Haupt-/Nebensachgebiet ([AbteilungAuswahl], schreibt das
/// FormControl `abteilung`), das Rechtsgebiet als lokaler State der View — es
/// steuert, ob die Unfall-Abschnitte sichtbar werden (kommt über
/// [rechtsgebiet]/[onRechtsgebietChanged]).
class AuftragSection extends StatelessWidget {
  final String rechtsgebiet;
  final ValueChanged<String> onRechtsgebietChanged;

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
          ],
        ),
        const AbteilungAuswahl(),
        SachgebietKatalogBuilder(
          builder: (context, katalog) => SearchableDropdown<String>(
            // Der Vorgabewert ('Verkehrsrecht') wird auf den Katalogeintrag
            // abgebildet, damit die Auswahl ihn anzeigt.
            value: () {
              for (final sachgebiet in katalog) {
                if (RechtsgebietWert.gleich(
                  sachgebiet.rechtsgebietVorschlag,
                  rechtsgebiet,
                )) {
                  return sachgebiet.rechtsgebietVorschlag;
                }
              }
              return rechtsgebiet;
            }(),
            labelText: 'Rechtsgebiet',
            hintText: 'Rechtsgebiet suchen oder auswählen',
            helperText:
                'Bei „Verkehrsrecht" werden Unfall- und Zentralruf-Felder '
                'eingeblendet.',
            helperMaxLines: 2,
            entries: [
              for (final sachgebiet in katalog)
                SearchableDropdownEntry(
                  value: sachgebiet.rechtsgebietVorschlag,
                  label: sachgebiet.rechtsgebietVorschlag,
                ),
            ],
            onChanged: (gebiet) =>
                onRechtsgebietChanged(gebiet ?? rechtsgebiet),
          ),
        ),
      ],
    );
  }
}
