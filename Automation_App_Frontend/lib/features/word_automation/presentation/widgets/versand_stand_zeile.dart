import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:flutter/material.dart';

/// Sagt im Abschlussdialog, ob die App die Mail schon versendet hat — und
/// wann, an wen (§4.7). Der Satz begründet das vorbelegte Häkchen: Ein
/// Kreuz, das ohne Erklärung gesetzt ist, wird nicht gelesen, sondern geglaubt.
class VersandStandZeile extends StatelessWidget {
  final EmailVersandErgebnis? versand;

  const VersandStandZeile({super.key, this.versand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ergebnis = versand;

    if (ergebnis == null) {
      return Text(
        'Die E-Mail zum Schreiben ist noch nicht versendet:',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Am ${zeitpunkt(ergebnis.gesendetAm)} an '
            '${ergebnis.empfaenger.join(', ')} versendet.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// „25.08.2026 um 14:12" — dieselbe Schreibweise wie im Postfach.
  static String zeitpunkt(DateTime wann) {
    String zwei(int wert) => wert.toString().padLeft(2, '0');
    return '${zwei(wann.day)}.${zwei(wann.month)}.${wann.year} um '
        '${zwei(wann.hour)}:${zwei(wann.minute)}';
  }
}
