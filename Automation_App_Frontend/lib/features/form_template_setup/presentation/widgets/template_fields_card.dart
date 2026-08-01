import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/tamplate_fields_table_header.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_field_item.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Karte mit den Eingabefeldern der Vorlage: Hinzufügen, sortierbare Liste
/// (Drag & Drop) und je Feld Typ/Pflicht/Löschen.
class TemplateFieldsCard extends StatelessWidget {
  final List<FieldData> fields;
  final FormGroup formGroup;
  final VoidCallback onAddField;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index, InputType? newValue) onTypeChanged;
  final void Function(int index, FeldDatenquelle? newValue) onDatenquelleChanged;
  final void Function(int index, bool? value) onRequiredChanged;
  final void Function(int index) onDelete;

  const TemplateFieldsCard({
    super.key,
    required this.fields,
    required this.formGroup,
    required this.onAddField,
    required this.onReorder,
    required this.onTypeChanged,
    required this.onDatenquelleChanged,
    required this.onRequiredChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              spacing: 10,
              children: [
                Icon(Icons.input, color: theme.colorScheme.primaryContainer),
                Text(
                  'Eingabefelder der Vorlage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                CustomRectangularButton(
                  icon: const Icon(Icons.add),
                  label: const Text('Neues Feld hinzufügen'),
                  onPressed: onAddField,
                ),
              ],
            ),
            const SizedBox(height: 24),

            fields.isEmpty
                ? const Center(child: Text('Keine Felder hinzugefügt'))
                : const TemplateFieldsTableHeader(),

            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: onReorder,
              // Das gezogene Element wird in ein Overlay außerhalb
              // des ReactiveForm gehoben — hier neu umschließen.
              proxyDecorator: (child, index, animation) {
                return ReactiveForm(
                  formGroup: formGroup,
                  child: Material(color: Colors.transparent, child: child),
                );
              },
              itemCount: fields.length,
              itemBuilder: (context, index) {
                return TemplateFieldItem(
                  key: ValueKey(fields[index].label),
                  index: index,
                  fieldData: fields[index],
                  onTypeChanged: (newValue) => onTypeChanged(index, newValue),
                  onDatenquelleChanged: (newValue) =>
                      onDatenquelleChanged(index, newValue),
                  onRequiredChanged: (value) => onRequiredChanged(index, value),
                  onDelete: () => onDelete(index),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
