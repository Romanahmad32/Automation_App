import 'package:flutter/material.dart';

/// Eine Zeile der Ergebnisansicht des Vollmacht-Dialogs: ein Häkchen oder ein
/// Kreuz und was passiert ist, wahlweise mit einem Knopf zum Nachsteuern.
class VollmachtErgebnisZeile extends StatelessWidget {
  final bool gelungen;
  final String text;
  final Widget? aktion;

  const VollmachtErgebnisZeile({
    super.key,
    required this.gelungen,
    required this.text,
    this.aktion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = gelungen
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Icon(
          gelungen ? Icons.check_circle_outline : Icons.error_outline,
          color: farbe,
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(text, style: theme.textTheme.bodyLarge),
              ?aktion,
            ],
          ),
        ),
      ],
    );
  }
}
