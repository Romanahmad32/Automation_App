import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Auswahl der beim gewählten Mandanten gespeicherten Kfz-Kennzeichen. Zeigt die
/// hinterlegten Kennzeichen als ChoiceChips; ein Tipp übernimmt das Kennzeichen
/// in das Eingabefeld (`formControlName`), ein erneuter Tipp auf das bereits
/// gewählte hebt die Auswahl wieder auf. Die freie Eingabe im Textfeld bleibt
/// unabhängig davon möglich.
class MandantKennzeichenAuswahl extends StatelessWidget {
  /// Die beim Mandanten gespeicherten Kennzeichen (mindestens eines).
  final List<String> kennzeichen;

  /// Reactive-Forms-Control, dessen Wert die Auswahl spiegelt/setzt.
  final String formControlName;

  /// Aufgerufen mit dem gewählten Kennzeichen bzw. einem leeren String, wenn
  /// die Auswahl wieder aufgehoben wird.
  final ValueChanged<String> onGewaehlt;

  const MandantKennzeichenAuswahl({
    super.key,
    required this.kennzeichen,
    required this.formControlName,
    required this.onGewaehlt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Gespeichertes Kennzeichen des Mandanten übernehmen:',
            style: theme.textTheme.bodySmall,
          ),
        ),
        ReactiveValueListenableBuilder<String>(
          formControlName: formControlName,
          builder: (context, control, child) {
            final aktuell = (control.value ?? '').trim().toUpperCase();
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kz in kennzeichen)
                  ChoiceChip(
                    avatar: const Icon(Icons.directions_car_outlined, size: 18),
                    label: Text(kz),
                    selected: aktuell == kz.trim().toUpperCase(),
                    onSelected: (selected) => onGewaehlt(selected ? kz : ''),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
