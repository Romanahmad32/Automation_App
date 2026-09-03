import 'package:automation_app/core/general_widgets/buttons/dropdowns/reactive_searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/speichern_button.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/abteilung_auswahl.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/widgets/register_ablage_felder.dart';
import 'package:automation_app/features/settings/presentation/widgets/sicherungs_ablage_felder.dart';
import 'package:automation_app/features/settings/presentation/widgets/stammordner_field.dart';
import 'package:automation_app/features/settings/presentation/widgets/vorlagen_ordner_feld.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Eigentliches Eingabeformular der Kanzlei-/Anfragerdaten. Findet die
/// FormControls über den umschließenden [ReactiveForm] (Context), braucht also
/// nur den Speicher-Status und den Speichern-Callback.
class KanzleiSettingsFormBody extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const KanzleiSettingsFormBody({
    super.key,
    required this.isSaving,
    required this.onSave,
  });

  static const List<String> _anfragertypen =
      KanzleiSettings.gueltigePersonentypen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormSection(
          icon: Icons.business,
          title: 'Kanzlei- / Anfragerdaten',
          subtitle:
              'Diese Daten füllen den Abschnitt "Anfrager" der '
              'Zentralruf-Anfrage automatisch aus.',
          children: [
            ReactiveSearchableDropdown<String>(
              formControlName: 'personentyp',
              labelText: 'Anfragertyp (Zentralruf)',
              entries: [
                for (final typ in _anfragertypen)
                  SearchableDropdownEntry(value: typ, label: typ),
              ],
            ),
            _field(
              'name',
              'Name der Kanzlei',
              validationMessages: {
                ValidationMessage.required: (_) =>
                    'Der Name ist ein Pflichtfeld',
              },
            ),
            _field('strasseHausnummer', 'Straße und Hausnummer'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _field('postleitzahl', 'PLZ')),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _field('ort', 'Ort')),
              ],
            ),
            _field(
              'emailAdresse',
              'E-Mail-Adresse',
              keyboardType: TextInputType.emailAddress,
              validationMessages: {
                ValidationMessage.email: (_) =>
                    'Bitte eine gültige E-Mail-Adresse eingeben',
              },
            ),
            _field(
              'telefonnummer',
              'Telefonnummer',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        FormSection(
          icon: Icons.tag,
          title: 'Referenz / Auftragsnummer',
          subtitle:
              'Die laufende Auftragsnummer und die Abteilung '
              'bilden die Referenz (Nr/Jahr Abteilung_Kennzeichen). '
              'Die Auftragsnummer wird in der Zentralruf-Anfrage '
              'automatisch vorbelegt und beim Abschluss eines '
              'Vorgangs um eins hochgezählt.',
          children: [
            _field(
              'laufendeAuftragsnummer',
              'Laufende Auftragsnummer',
              keyboardType: TextInputType.number,
              validationMessages: {
                ValidationMessage.required: (_) => 'Pflichtfeld',
                ValidationMessage.number: (_) => 'Bitte eine Zahl eingeben',
              },
            ),
            // Die Abteilung ist eine Auswahl aus dem Sachgebietskatalog
            // (§7.1): Hauptsachgebiet als Pflicht, Nebensachgebiet optional
            // (Überschneidung wie C05/3). Schreibt weiterhin in dasselbe
            // FormControl 'abteilung'.
            const AbteilungAuswahl(),
          ],
        ),
        FormSection(
          icon: Icons.folder_special,
          title: 'Aktensystem',
          subtitle:
              'Stammordner, unter dem pro Mandant eine Akte '
              '(Unterordner) liegt. Die fertigen Dokumente '
              'werden hier automatisch abgelegt. Ohne '
              'Stammordner ist nur das manuelle Speichern '
              'möglich.',
          children: const [StammordnerField()],
        ),
        FormSection(
          icon: Icons.description_outlined,
          title: 'Vorlagen',
          subtitle:
              'Ordner, in dem die Word-Vorlagen liegen. Er wird bei jeder '
              'Sicherung mitgenommen; Vorlagenpfade werden relativ zu ihm '
              'gespeichert, damit dieselbe Sicherung auch auf einem zweiten '
              'Rechner funktioniert. Leer heißt: die App verwaltet die '
              'Vorlagen selbst (AppData).',
          children: const [VorlagenOrdnerFeld()],
        ),
        FormSection(
          icon: Icons.cloud_sync_outlined,
          title: 'Register-Ablage',
          subtitle:
              'Das Sachgebiete-Register wird zusätzlich als Word- und '
              'PDF-Datei in diesen Ordner geschrieben. Liegt er im '
              'synchronisierten Bereich (z. B. OneDrive), ist das Register '
              'unterwegs lesbar — die App spricht dabei mit keiner Cloud, sie '
              'legt nur eine Datei ab. Gepflegt wird das Register weiterhin '
              'ausschließlich hier in der App; die Datei dort ist ein Spiegel.',
          children: const [RegisterAblageFelder()],
        ),
        FormSection(
          icon: Icons.backup_outlined,
          title: 'Sicherungsablage',
          subtitle:
              'Beim Beenden legt die App den gesamten Stand als Sicherung in '
              'diesen Ordner. Liegt er im synchronisierten Bereich (z. B. '
              'OneDrive), bietet der zweite Rechner ihn beim Öffnen zur '
              'Übernahme an — die App fragt dabei nach, bevor sie etwas '
              'ersetzt. Leer heißt: nur Sichern auf Knopfdruck.',
          children: const [SicherungsAblageFelder()],
        ),
        ReactiveFormConsumer(
          builder: (context, form, child) => SpeichernButton(
            speichert: isSaving,
            onSpeichern: form.valid ? onSave : null,
          ),
        ),
      ],
    );
  }

  Widget _field(
    String controlName,
    String label, {
    TextInputType? keyboardType,
    Map<String, String Function(Object)>? validationMessages,
  }) {
    return GeneralTextField<String>(
      formControlName: controlName,
      labelText: label,
      keyboardType: keyboardType,
      validationMessages: validationMessages,
    );
  }
}
