import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
import 'package:flutter/material.dart';

/// Abschnitt „Unfallhergang": Unfallort, -uhrzeit und polizeiliche
/// Vorgangsnummer für die spätere Akten- und Schreibenerstellung. Wird bei
/// Verkehrsrecht eingeblendet; alle Felder sind optional und werden am Vorgang
/// persistiert. Felder über Reactive-Forms-Controls.
class UnfallhergangSection extends StatelessWidget {
  const UnfallhergangSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.car_crash_outlined,
      title: 'Unfallhergang',
      subtitle:
          'Optional — Angaben zum Unfall für die spätere Akten- und '
          'Schreibenerstellung.',
      children: [
        const GeneralTextField<String>(
          labelText:
              'Unfallort (Straße und Ort, z. B. Am Ulmenrück, Frankfurt am Main)',
          formControlName: 'unfallort',
        ),
        GeneralTextField<String>(
          labelText: 'Unfalluhrzeit (z. B. 14:05)',
          formControlName: 'unfalluhrzeit',
          validationMessages: uhrzeitMessages,
        ),
        GeneralTextField<String>(
          labelText: 'Polizeiliche Vorgangsnummer (z. B. VU/1234567/2026)',
          formControlName: 'polizeiVorgangsnummer',
          validationMessages: vorgangsnummerMessages,
        ),
      ],
    );
  }
}
