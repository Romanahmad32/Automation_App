import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';

class FormTemplateBuilder extends StatelessWidget {
  final FormTemplate? formTemplate;
  final Widget? submitButtonLabel;
  final void Function(Map<String, String>)? onSubmitted;

  /// Vorbelegte Werte je Feldname (z. B. aus der Zentralruf-Antwort);
  /// sichtbar und vom Nutzer änderbar.
  final Map<String, String> initialValues;

  /// Herkunft je vorbelegtem Feldname (z. B. „aus der Zentralruf-Antwort"),
  /// als Hinweis unter dem Feld angezeigt — der Anwalt sieht so je Feld,
  /// welchem Datenbestand er vertraut, und erkennt falsche Vorbelegungen
  /// sofort (Punkt 7 des Verbesserungsplans).
  final Map<String, String> initialValueQuellen;

  const FormTemplateBuilder({
    super.key,
    required this.formTemplate,
    this.submitButtonLabel,
    this.onSubmitted,
    this.initialValues = const {},
    this.initialValueQuellen = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (formTemplate == null) {
      return const SizedBox.shrink();
    }

    // Use a unique key for the form group based on the template ID to ensure
    // it resets when the template changes (or when new prefill values arrive).
    return ReactiveFormBuilder(
      key: ValueKey('${formTemplate!.id}#$_initialValuesSignature'),
      form: () => FormGroup(
        Map.fromEntries(
          formTemplate!.fields.map(
            (e) => MapEntry(
              e.label,
              FormControl<String>(
                // Vorgangsdaten (Zentralruf-Antwort) haben Vorrang; sonst
                // Datumsfelder mit heutigem Datum vorbelegen – sichtbar und
                // änderbar, statt es beim Erzeugen unsichtbar einzusetzen.
                value:
                    initialValues[e.label] ??
                    (e.inputType == InputType.date
                        ? GermanDateField.formatDate(_defaultDateFor(e.label))
                        : null),
                validators: [
                  if (e.required) Validators.required,
                  if (e.inputType == InputType.date)
                    GermanDateField.validator(),
                ],
              ),
            ),
          ),
        ),
      ),
      builder: (context, formGroup, child) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            spacing: 16,
            children: [
              ...formTemplate!.fields.map((field) {
                return _buildField(context, field);
              }),
              const SizedBox(height: 8),
              ReactiveFormConsumer(
                builder: (context, formGroup, child) {
                  return CustomRectangularButton(
                    label: submitButtonLabel ?? const Text('Formular absenden'),
                    onPressed: formGroup.valid
                        ? () {
                            final data = formGroup.value.map(
                              (key, value) =>
                                  MapEntry(key, value?.toString() ?? ''),
                            );
                            onSubmitted?.call(data);
                          }
                        : null,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Stabile Signatur der Vorbelegung: gleiche Werte → gleicher Key, sonst
  /// würde jedes Rebuild das Formular (und damit Nutzereingaben) zurücksetzen.
  String get _initialValuesSignature =>
      (initialValues.entries.map((e) => '${e.key}=${e.value}').toList()..sort())
          .join('|');

  Widget _buildField(BuildContext context, FieldData field) {
    final validationMessages = field.required
        ? {
            ValidationMessage.required: (Object _) =>
                '${field.label} ist ein Pflichtfeld',
          }
        : <String, String Function(Object)>{};

    switch (field.inputType) {
      case InputType.date:
        // Direkt tippbar (Format prüft GermanDateField.validator);
        // das Kalender-Icon öffnet zusätzlich den Auswahl-Dialog.
        return GermanDateField(
          formControlName: field.label,
          labelText: field.label,
          helperText: _helperText(field),
          validationMessages: validationMessages,
        );
      case InputType.integer:
        return GeneralTextField<String>(
          formControlName: field.label,
          labelText: field.label,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validationMessages: validationMessages,
          inputDecoration: _decoration(field),
        );
      case InputType.decimal:
        return GeneralTextField<String>(
          formControlName: field.label,
          labelText: field.label,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          validationMessages: validationMessages,
          inputDecoration: _decoration(field),
        );
      case InputType.text:
        return GeneralTextField<String>(
          formControlName: field.label,
          labelText: field.label,
          keyboardType: TextInputType.text,
          validationMessages: validationMessages,
          inputDecoration: _decoration(field),
        );
    }
  }

  InputDecoration _decoration(FieldData field) =>
      InputDecoration(helperText: _helperText(field));

  /// Hinweiszeile unter dem Feld: Pflichtfeld-Markierung und — falls das Feld
  /// vorbelegt wurde — die Herkunft des Werts.
  String? _helperText(FieldData field) {
    final quelle = initialValueQuellen[field.label];
    final pflicht = field.required ? '* Pflichtfeld' : null;
    if (quelle == null) return pflicht;
    final vorbelegt = 'Vorbelegt $quelle';
    return pflicht == null ? vorbelegt : '$pflicht · $vorbelegt';
  }

  /// Zahlungsfrist-Felder werden mit Generierungsdatum + 5 Wochen vorbelegt,
  /// alle anderen Datumsfelder mit dem heutigen Datum.
  static DateTime _defaultDateFor(String label) =>
      label.toLowerCase().contains('zahlungsfrist')
      ? DateTime.now().add(const Duration(days: 35))
      : DateTime.now();
}
