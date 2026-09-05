import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

class TemplateNameCard extends StatelessWidget {
  /// Eine Zeile unter dem Namensfeld — null heißt: keine.
  ///
  /// Gedacht für den Namensvorschlag aus dem Dateinamen („Vorschlag aus
  /// HGN.docx — bei Bedarf anpassen", #104 Stufe 3c). Der Aufrufer entscheidet,
  /// wann er steht; die Karte zeigt nur an, was sie bekommt — sonst müsste sie
  /// den Stand des Editors kennen, um eine Textzeile zu setzen.
  final String? hinweis;

  const TemplateNameCard({super.key, this.hinweis});

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
              // Der Hinweis steht **unter** dem Feld und in dessen Breite: Er
              // gehört zu dem, was darin steht, nicht zur Karte.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  GeneralTextField(
                    formControlName: 'templateName',
                    validationMessages: {
                      ValidationMessage.required: (_) =>
                          'Der Vorlagenname darf nicht leer sein.',
                    },
                  ),
                  if (hinweis != null)
                    Text(
                      hinweis!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
