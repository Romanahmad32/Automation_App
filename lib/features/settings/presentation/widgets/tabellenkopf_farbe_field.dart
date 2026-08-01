import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Auswahl der Titelzeilen-Farbe der Schadensaufstellung: vordefinierte
/// Farbfelder plus freie Hex-Eingabe mit Live-Vorschau.
class TabellenkopfFarbeField extends StatelessWidget {
  const TabellenkopfFarbeField({super.key});

  static const List<(String, String)> _vorschlaege = [
    ('D9D9D9', 'Grau (Standard)'),
    ('B4C6E7', 'Blau'),
    ('C6E0B4', 'Grün'),
    ('FFE699', 'Gelb'),
    ('F8CBAD', 'Orange'),
  ];

  static Color? _parse(String? hex) {
    final value = hex?.trim().replaceFirst('#', '') ?? '';
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(0xFF000000 | int.parse(value, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReactiveValueListenableBuilder<String>(
      formControlName: 'tabellenkopfFarbeHex',
      builder: (context, control, _) {
        final current = (control.value ?? '')
            .replaceFirst('#', '')
            .toUpperCase();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (hex, label) in _vorschlaege)
                  Tooltip(
                    message: label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => control.value = hex,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _parse(hex),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: current == hex
                                ? theme.colorScheme.primary
                                : theme.dividerColor,
                            width: current == hex ? 3 : 1,
                          ),
                        ),
                        child: current == hex
                            ? const Icon(Icons.check, size: 18)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            GeneralTextField<String>(
              formControlName: 'tabellenkopfFarbeHex',
              labelText: 'Farbe als Hex-Wert (RRGGBB)',
              validationMessages: {
                ValidationMessage.required: (_) =>
                    'Bitte einen Hex-Farbwert angeben (z. B. D9D9D9)',
                ValidationMessage.pattern: (_) =>
                    'Ungültiger Farbwert — erwartet wird "RRGGBB" (z. B. D9D9D9)',
              },
              inputDecoration: InputDecoration(
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      color: _parse(control.value) ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.dividerColor),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
