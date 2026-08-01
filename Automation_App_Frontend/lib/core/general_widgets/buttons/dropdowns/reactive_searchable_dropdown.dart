import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import 'searchable_dropdown.dart';

/// `reactive_forms`-Anbindung des [SearchableDropdown]: bindet die Auswahl an
/// das FormControl [formControlName] und übernimmt geänderte Werte zurück.
class ReactiveSearchableDropdown<T> extends StatelessWidget {
  final String formControlName;
  final List<SearchableDropdownEntry<T>> entries;
  final String? labelText;
  final String hintText;
  final String? helperText;
  final Widget? leadingIcon;

  const ReactiveSearchableDropdown({
    super.key,
    required this.formControlName,
    required this.entries,
    this.labelText,
    this.hintText = 'Suchen oder auswählen',
    this.helperText,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ReactiveValueListenableBuilder<T>(
      formControlName: formControlName,
      builder: (context, control, child) {
        return SearchableDropdown<T>(
          value: control.value,
          entries: entries,
          labelText: labelText,
          hintText: hintText,
          helperText: helperText,
          leadingIcon: leadingIcon,
          onChanged: (value) {
            control.value = value;
            control.markAsTouched();
          },
        );
      },
    );
  }
}
