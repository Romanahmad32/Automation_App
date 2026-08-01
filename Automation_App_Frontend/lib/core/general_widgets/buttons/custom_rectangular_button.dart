import 'package:flutter/material.dart';

class CustomRectangularButton extends StatelessWidget {
  final Icon? icon;
  final Widget label;
  final void Function()? onPressed;
  final ButtonStyle? buttonStyle;
  final void Function(ButtonStyle)? onButtonStyleChanged;

  const CustomRectangularButton({
    super.key,
    this.onPressed,
    this.icon,
    required this.label,
    this.buttonStyle,
    this.onButtonStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle =
        this.buttonStyle ??
            ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
              ),
              backgroundColor: Theme
                  .of(context)
                  .colorScheme
                  .primaryContainer,
              foregroundColor: Theme
                  .of(context)
                  .colorScheme
                  .onPrimaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              elevation: 2,
            );
    if (icon == null) {
      return ElevatedButton(
        onPressed: onPressed,
        style: buttonStyle,
        child: label,
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: label,
      style: buttonStyle,
    );
  }
}
