import 'package:automation_app/core/general_widgets/form/reactive_text_eingabe.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';

class GeneralTextField<T> extends StatelessWidget {
  final String? labelText;
  final String? formControlName;
  final InputDecoration? inputDecoration;
  final Map<String, String Function(Object)>? validationMessages;
  final void Function(FormControl<T>)? onChanged;
  final ControlValueAccessor<T, String>? valueAccessor;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final bool obscureText;

  const GeneralTextField({
    super.key,
    this.labelText,
    this.formControlName,
    this.inputDecoration,
    this.validationMessages,
    this.onChanged,
    this.valueAccessor,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReactiveTextEingabe<T>(
      formControlName: formControlName,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      obscureText: obscureText,
      decoration: (inputDecoration ?? const InputDecoration()).copyWith(
        labelText: labelText ?? '',
        border: theme.inputDecorationTheme.border ?? const OutlineInputBorder(),
      ),
      validationMessages: validationMessages,
      onChanged: onChanged,
      valueAccessor: valueAccessor,
    );
  }
}
