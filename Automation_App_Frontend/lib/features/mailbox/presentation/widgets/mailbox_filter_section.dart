import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Welcher Ordner überwacht und welche Mails ausgewertet werden — gilt für
/// beide Anmeldewege (Gmail und Outlook).
class MailboxFilterSection extends StatelessWidget {
  const MailboxFilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.filter_alt,
      title: 'Überwachung',
      subtitle:
          'Standard: Posteingang, erkannt werden Mails mit „Zentralruf“ im '
          'Betreff.',
      children: [
        GeneralTextField<String>(
          formControlName: 'folder',
          labelText: 'Ordner',
          validationMessages: {
            ValidationMessage.required: (_) => 'Pflichtfeld',
          },
        ),
        GeneralTextField<String>(
          formControlName: 'subjectFilter',
          labelText: 'Betreff-Filter (leer = alle Mails prüfen)',
        ),
      ],
    );
  }
}
