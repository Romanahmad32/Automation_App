import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_kennzeichen_auswahl.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_speichern_button.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_vorschlag_banner.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
import 'package:flutter/material.dart';

/// Abschnitt „Mandant": Stammdaten des Mandanten (im Verkehrsunfall zugleich der
/// Geschädigte). Immer sichtbar. Lässt sich aus dem Register vorbefüllen oder
/// frei erfassen; nicht verknüpfte Daten bietet die View beim Speichern als
/// neuen Mandanten an. Auswahl/Schalter meldet das Widget über Callbacks; die
/// Textfelder laufen über Reactive-Forms-Controls.
class MandantSection extends StatelessWidget {
  final List<Mandant> mandanten;
  final int? selectedMandantId;
  final ValueChanged<Mandant> onMandantGewaehlt;

  /// Hebt die Verknüpfung zum gewählten Mandanten auf (Auswahl „(neuer Mandant)").
  final VoidCallback onAuswahlAufheben;

  /// Übernimmt ein gespeichertes Kennzeichen des gewählten Mandanten in das
  /// Kennzeichen-Feld (leerer String hebt die Auswahl auf).
  final ValueChanged<String> onKennzeichenGewaehlt;

  /// Aktuelles Rechtsgebiet (für das Auslesen der Formularwerte im Button).
  final Rechtsgebiet rechtsgebiet;

  /// Bestätigte Mandanten-Aktion (Anlegen/Aktualisieren) aus dem Karten-Button.
  final void Function(MandantAenderungsart art, VorgangStartenDaten daten)
  onMandantBestaetigt;

  const MandantSection({
    super.key,
    required this.mandanten,
    required this.selectedMandantId,
    required this.onMandantGewaehlt,
    required this.onAuswahlAufheben,
    required this.onKennzeichenGewaehlt,
    required this.rechtsgebiet,
    required this.onMandantBestaetigt,
  });

  /// Der aktuell verknüpfte Mandant aus dem Register (oder null = neuer Mandant).
  Mandant? get _gewaehlterMandant {
    for (final mandant in mandanten) {
      if (mandant.id == selectedMandantId) return mandant;
    }
    return null;
  }

  /// Die beim aktuell gewählten Mandanten gespeicherten Kennzeichen (0..n).
  List<String> get _gespeicherteKennzeichen =>
      _gewaehlterMandant?.kennzeichen ?? const [];

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.person_outline,
      title: 'Mandant',
      subtitle:
          'Aus dem Register übernehmen oder neu erfassen. Neue oder geänderte '
          'Daten werden beim Speichern für den Mandanten hinterlegt.',
      children: [
        if (mandanten.isNotEmpty)
          SearchableDropdown<int>(
            value: selectedMandantId,
            labelText: 'Aus Mandanten übernehmen',
            hintText: 'Mandant suchen oder „(neuer Mandant)"',
            helperText:
                'Füllt die Felder aus dem Register; Änderungen am Namen lösen '
                'die Verknüpfung.',
            helperMaxLines: 2,
            entries: [
              const SearchableDropdownEntry<int>(
                value: -1,
                label: '(neuer Mandant)',
              ),
              for (final mandant in mandanten)
                SearchableDropdownEntry(
                  value: mandant.id,
                  label: mandant.anzeigename,
                ),
            ],
            onChanged: (id) {
              if (id == null || id == -1) {
                onAuswahlAufheben();
                return;
              }
              onMandantGewaehlt(mandanten.firstWhere((m) => m.id == id));
            },
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              child: GeneralTextField<String>(
                labelText: 'Vorname',
                formControlName: 'mandantVorname',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GeneralTextField<String>(
                labelText: 'Nachname',
                formControlName: 'mandantNachname',
              ),
            ),
          ],
        ),
        // Wiedererkennung bei freier Eingabe: Passen Name oder Kennzeichen zu
        // einem Registereintrag, wird die Übernahme angeboten (nur solange
        // kein Mandant verknüpft ist — sonst wäre der Hinweis redundant).
        if (selectedMandantId == null)
          MandantVorschlagBanner(
            mandanten: mandanten,
            onUebernehmen: onMandantGewaehlt,
          ),
        const GeneralTextField<String>(
          labelText: 'Straße und Hausnummer',
          formControlName: 'mandantStrasse',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              flex: 2,
              child: GeneralTextField<String>(
                labelText: 'PLZ',
                formControlName: 'mandantPlz',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: GeneralTextField<String>(
                labelText: 'Ort',
                formControlName: 'mandantOrt',
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              child: GeneralTextField<String>(
                labelText: 'E-Mail',
                formControlName: 'mandantEmail',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GeneralTextField<String>(
                labelText: 'Telefon',
                formControlName: 'mandantTelefon',
              ),
            ),
          ],
        ),
        if (_gespeicherteKennzeichen.isNotEmpty)
          MandantKennzeichenAuswahl(
            kennzeichen: _gespeicherteKennzeichen,
            formControlName: 'mandantKennzeichen',
            onGewaehlt: onKennzeichenGewaehlt,
          ),
        GeneralTextField<String>(
          labelText: 'Kfz-Kennzeichen des Mandanten (z. B. HG-E 1427)',
          formControlName: 'mandantKennzeichen',
          validationMessages: kennzeichenMessages,
        ),
        MandantSpeichernButton(
          rechtsgebiet: rechtsgebiet,
          gewaehlterMandant: _gewaehlterMandant,
          onBestaetigt: onMandantBestaetigt,
        ),
      ],
    );
  }
}
