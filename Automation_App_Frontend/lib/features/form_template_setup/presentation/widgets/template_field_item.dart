import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

class TemplateFieldItem extends StatelessWidget {
  final int index;
  final FieldData fieldData;
  final ValueChanged<InputType?> onTypeChanged;
  final ValueChanged<FeldDatenquelle?> onDatenquelleChanged;
  final ValueChanged<bool?> onRequiredChanged;
  final VoidCallback onDelete;

  const TemplateFieldItem({
    super.key,
    required this.index,
    required this.fieldData,
    required this.onTypeChanged,
    required this.onDatenquelleChanged,
    required this.onRequiredChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(2.0),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        spacing: 10,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  Icons.drag_indicator,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: GeneralTextField(
                formControlName: fieldData.label,
                inputDecoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      'Der Feldname darf nicht leer sein.',
                },
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: SearchableDropdown<InputType>(
              value: fieldData.inputType,
              hintText: 'Typ suchen oder auswählen',
              entries: [
                for (final type in InputType.values)
                  SearchableDropdownEntry(value: type, label: type.displayName),
              ],
              onChanged: onTypeChanged,
            ),
          ),

          Expanded(
            flex: 3,
            child: SearchableDropdown<FeldDatenquelle>(
              value: fieldData.datenquelle,
              hintText: 'Datenquelle suchen oder auswählen',
              entries: [
                for (final quelle in FeldDatenquelle.values)
                  SearchableDropdownEntry(
                    value: quelle,
                    label: quelle.displayName,
                  ),
              ],
              onChanged: onDatenquelleChanged,
            ),
          ),

          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => onRequiredChanged.call(!fieldData.required),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Row(
                children: [
                  Checkbox(
                    value: fieldData.required,
                    activeColor: theme.colorScheme.primary,
                    onChanged: onRequiredChanged,
                  ),
                  Text(
                    'ERFORDERLICH',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          IconButton(
            icon: Icon(Icons.delete, color: theme.colorScheme.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
