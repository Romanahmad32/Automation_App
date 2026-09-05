import 'package:automation_app/core/general_widgets/buttons/dropdowns/reactive_searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/speichern_button.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/abteilung_auswahl.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_reiter.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_sektion.dart';
import 'package:automation_app/features/settings/presentation/widgets/register_spiegel_felder.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Eigentliches Eingabeformular der Kanzlei-/Anfragerdaten. Findet die
/// FormControls über den umschließenden [ReactiveForm] (Context), braucht also
/// nur den Speicher-Status und den Speichern-Callback.
///
/// Die Karten sind in zwei Themen geteilt, die auf einem breiten Schirm
/// nebeneinander stehen: links **wer** die Kanzlei ist (Anfragerdaten,
/// Referenz), rechts **wo** ihre Dateien liegen (`OrdnerSektion`, dazu die
/// Einstellungen des Register-Spiegels). Wird es eng, laufen sie in dieser
/// Reihenfolge untereinander.
///
/// Bis #103 stand jeder der vier Ordner in einer eigenen Karte, der
/// Akten-Stammordner sogar in der linken Spalte — verteilt über zwei Spalten
/// war die Einrichtung eine Suche danach, welcher Ordner wozu gehört. Jetzt
/// steht die Ordnerwahl an genau einer Stelle; die Höhen der beiden Spalten
/// gleichen sich dadurch nicht mehr so genau aus wie vorher, und das ist der
/// bewusst gezahlte Preis.
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
    return EinstellungenReiter(
      aktion: ReactiveFormConsumer(
        builder: (context, form, child) => SpeichernButton(
          kompakt: true,
          speichert: isSaving,
          onSpeichern: form.valid ? onSave : null,
        ),
      ),
      links: [
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
      ],
      rechts: const [
        OrdnerSektion(),
        FormSection(
          icon: Icons.cloud_sync_outlined,
          title: 'Register-Spiegel',
          subtitle:
              'Das Sachgebiete-Register entsteht zusätzlich als Word- und '
              'PDF-Datei — unter dem Ordner für die App-Daten, sofern oben '
              'kein eigener gewählt ist. Liegt er im synchronisierten Bereich, '
              'ist das Register unterwegs lesbar; die App spricht dabei mit '
              'keiner Cloud, sie legt nur eine Datei ab. Gepflegt wird das '
              'Register ausschließlich hier in der App, die Datei dort ist ein '
              'Spiegel.',
          children: [RegisterSpiegelFelder()],
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
