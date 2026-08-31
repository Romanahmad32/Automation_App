import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/sachgebiet_katalog_builder.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die Abteilung als Auswahl statt Freitext (§7.1): ein Pflicht-Dropdown
/// Hauptsachgebiet und ein optionales Nebensachgebiet, zusammengesetzt zu dem
/// **einen** String, den das Referenzformat erwartet (`C05` + `C03` → `C05/3`).
/// Schreibt in das bestehende FormControl — für Formular, Validierung und
/// Speichern ändert sich nichts.
///
/// Ein gespeicherter Wert außerhalb des Katalogs (Altbestand, Tippfehler)
/// bleibt als eigener Eintrag wählbar, statt still zu verschwinden; der
/// Fehlerfall des Katalogs kommt aus dem [SachgebietKatalogBuilder].
class AbteilungAuswahl extends StatelessWidget {
  final String formControlName;

  const AbteilungAuswahl({super.key, this.formControlName = 'abteilung'});

  /// Sentinel für „kein Nebensachgebiet" — [SearchableDropdown] meldet `null`
  /// nur beim Löschen des Suchtexts, deshalb ein eigener Wert.
  static const String keinNeben = '';

  @override
  Widget build(BuildContext context) {
    return SachgebietKatalogBuilder(
      builder: (context, katalog) => ReactiveValueListenableBuilder<String>(
        formControlName: formControlName,
        builder: (context, control, _) {
          final teile = AbteilungKuerzel.zerlege(control.value);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SearchableDropdown<String>(
                  value: teile.haupt.isEmpty ? null : teile.haupt,
                  labelText: 'Hauptsachgebiet (Abteilung)',
                  hintText: 'Kürzel oder Sachgebiet suchen',
                  entries: _eintraege(katalog, teile.haupt),
                  onChanged: (haupt) => control.updateValue(
                    AbteilungKuerzel.setzeZusammen(
                      haupt ?? teile.haupt,
                      teile.neben,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SearchableDropdown<String>(
                  value: teile.neben ?? keinNeben,
                  labelText: 'Nebensachgebiet',
                  hintText: 'Überschneidung, z. B. C05/3',
                  entries: [
                    const SearchableDropdownEntry(
                      value: keinNeben,
                      label: 'Keins',
                    ),
                    ..._eintraege(katalog, teile.neben),
                  ],
                  onChanged: (neben) => control.updateValue(
                    AbteilungKuerzel.setzeZusammen(
                      teile.haupt,
                      (neben == null || neben == keinNeben) ? null : neben,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Katalogeinträge als Dropdown-Einträge; ein gespeichertes Kürzel außerhalb
  /// des Katalogs kommt als eigener Eintrag dazu (Notnagel für Altbestand).
  List<SearchableDropdownEntry<String>> _eintraege(
    List<Sachgebiet> katalog,
    String? gespeichert,
  ) {
    final eintraege = [
      for (final sachgebiet in katalog)
        SearchableDropdownEntry(
          value: sachgebiet.kuerzel,
          label: '${sachgebiet.kuerzel} — ${sachgebiet.name}',
        ),
    ];
    final fehlt =
        gespeichert != null &&
        gespeichert.isNotEmpty &&
        !katalog.any((s) => s.kuerzel == gespeichert);
    if (fehlt) {
      eintraege.add(
        SearchableDropdownEntry(
          value: gespeichert,
          label: '$gespeichert — nicht im Katalog',
        ),
      );
    }
    return eintraege;
  }
}
