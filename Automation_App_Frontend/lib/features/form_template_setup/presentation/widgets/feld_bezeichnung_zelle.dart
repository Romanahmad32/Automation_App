import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_vorkommen.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_vorkommen_beobachter.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/feld_vorkommen_pille.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die breiteste Zelle der Feldzeile: der Feldname, und daneben — sobald das
/// Vorkommen bekannt ist — das Kennzeichen, in welcher Word-Datei der
/// Platzhalter steht.
///
/// Der Name ist zugleich der Platzhaltername; was hier steht, sucht das
/// Backend beim Erzeugen in der Word-Datei. Deshalb gehört das Kennzeichen
/// genau hierher und nicht unter die Zeile: Es sagt etwas über **diesen**
/// Text.
///
/// Warum die Zelle das Vorkommen selbst beobachtet, statt einfach ein
/// [FeldVorkommenBeobachter]-Kennzeichen danebenzustellen: Nur wer vor dem
/// Aufbau weiß, ob die Pille kommt, kann dem Eingabefeld den ganzen Rest der
/// Spalte geben. Ein Platzhalter „für den Fall der Fälle" liesse leer stehen,
/// solange Name oder Platzhalterlisten noch fehlen.
class FeldBezeichnungZelle extends StatelessWidget {
  /// Schlüssel des reactive_forms-Controls, in dem der Feldname steht.
  final String formControlName;

  /// Klick auf die Warnung — führt zur Zuordnung (#36).
  final VoidCallback? onZuordnen;

  const FeldBezeichnungZelle({
    super.key,
    required this.formControlName,
    this.onZuordnen,
  });

  /// Höchstanteil der Spalte, den die Warnung neben dem Namen nehmen darf.
  static const double _pillenAnteil = 0.55;

  @override
  Widget build(BuildContext context) {
    return FeldVorkommenBeobachter(
      formControlName: formControlName,
      builder: (context, vorkommen) => LayoutBuilder(
        builder: (context, grenzen) => Row(
          spacing: 6,
          children: [
            Expanded(
              child: GeneralTextField(
                formControlName: formControlName,
                inputDecoration: const InputDecoration(isDense: true),
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      'Der Feldname darf nicht leer sein.',
                },
              ),
            ),
            if (vorkommen != null)
              ConstrainedBox(
                // Die Pille darf höchstens gut die Hälfte der Spalte nehmen.
                // Eine feste Obergrenze allein reichte nicht: Bei 700 px
                // Fenster und der größten Schriftstufe (Issue #57) ist die
                // ganze Spalte schmaler als die Pille breit sein dürfte, und
                // das `Expanded` daneben kann nicht auf negative Breite
                // schrumpfen — die Zeile liefe über.
                constraints: BoxConstraints(
                  maxWidth: grenzen.maxWidth * _pillenAnteil,
                ),
                child: FeldVorkommenPille(
                  vorkommen: vorkommen,
                  // Der Klickweg zur Zuordnung (#36) gilt nur dem Befund, der
                  // etwas kostet — die drei anderen Fälle sind reine
                  // Auskunft und bleiben stumm.
                  onZuordnen: vorkommen == FeldVorkommen.inKeinerDatei
                      ? onZuordnen
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
