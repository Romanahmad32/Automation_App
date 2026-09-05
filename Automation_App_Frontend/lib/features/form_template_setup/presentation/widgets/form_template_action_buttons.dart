import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

class FormTemplateActionButtons extends StatelessWidget {
  final VoidCallback onCancel;
  final List<FieldData> fields;
  final int? existingItemId; // 1. Added optional ID
  final String? wordFilePathOhneAuflistung;
  final String? wordFilePathMitAuflistung;

  const FormTemplateActionButtons({
    super.key,
    required this.onCancel,
    required this.fields,
    this.existingItemId, // 2. Add to constructor
    this.wordFilePathOhneAuflistung,
    this.wordFilePathMitAuflistung,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = existingItemId != null; // 3. Helper to check mode

    return Row(
      spacing: 15,
      children: [
        CustomRectangularButton(
          onPressed: onCancel,
          buttonStyle: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
            ),
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          label: const Text('Abbrechen'),
        ),
        ReactiveFormConsumer(
          builder: (context, formGroup, child) {
            return CustomRectangularButton(
              // 4. Dynamically change the button label
              label: Text(
                isEditing ? 'Vorlage speichern' : 'Vorlage erstellen',
              ),
              onPressed: formGroup.valid
                  ? () {
                      if (wordFilePathOhneAuflistung == null &&
                          wordFilePathMitAuflistung == null) {
                        Rueckmeldung.zeigeHinweis(
                          context,
                          'Bitte mindestens eine Word-Datei verknüpfen '
                          '(ohne und/oder mit Auflistung).',
                        );
                        return;
                      }
                      // Das vorhandene Feld **fortschreiben**, nicht neu
                      // bauen: `copyWith` reicht die Datums-Vorbelegung
                      // ausdrücklich durch, ein Neubau liesse sie still fallen
                      // — und weil `toJson` den Schlüssel dann gar nicht
                      // schreibt, wäre der Verlust von „nie eingestellt" nicht
                      // zu unterscheiden (§5.3, #105).
                      //
                      // Der Laufindex ist zugleich die Reihenfolge; das
                      // frühere `indexOf` suchte jedes Feld unnötig erneut
                      // in der Liste (quadratischer Aufwand).
                      final List<FieldData> formData = [
                        for (final (index, field) in fields.indexed)
                          field.copyWith(
                            order: index,
                            // Solange die Seite offen ist, steht in
                            // `field.label` der Control-Schlüssel; der echte
                            // Feldname liegt im Wert des Controls.
                            label:
                                formGroup.control(field.label).value as String,
                          ),
                      ];

                      context.read<FormTemplateDataBloc>().add(
                        SubmitFormTemplateDataEvent(
                          existingItemId: existingItemId,
                          // 6. Pass the ID to the BLoC event
                          templateName:
                              formGroup.control('templateName').value
                                  as String?,
                          formData: formData,
                          wordFilePathOhneAuflistung:
                              wordFilePathOhneAuflistung,
                          wordFilePathMitAuflistung: wordFilePathMitAuflistung,
                        ),
                      );
                    }
                  : null,
            );
          },
        ),
      ],
    );
  }
}
