import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

class TemplateNameCard extends StatelessWidget {
  const TemplateNameCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 15,
          children: [
            Row(
              spacing: 10,
              children: [
                Icon(Icons.info, color: theme.colorScheme.primaryContainer),
                Text(
                  'NAME DER VORLAGE',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(
              width: 400,
              child: GeneralTextField(
                formControlName: 'templateName',
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      'Der Vorlagenname darf nicht leer sein.',
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
