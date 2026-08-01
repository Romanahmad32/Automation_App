import 'package:flutter/material.dart';
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
    return ReactiveTextField<T>(
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
