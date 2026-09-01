import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/core/general_widgets/form/german_date_field.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:flutter/material.dart';

/// Die Leiste über dem Ausfüll-Formular, wenn zum Vorgang ein angefangener
/// Stand vorliegt: „Angefangener Stand von 14:32 Uhr — Weiterarbeiten /
/// Verwerfen".
///
/// Der Stand wird **angeboten**, nicht eingesetzt. Ein stilles Wiederherstellen
/// wäre die bequemere Variante und die schlechtere: Der Anwalt sähe Werte im
/// Formular, ohne zu wissen, ob sie aus der Zentralruf-Antwort, aus einem
/// früheren Schreiben oder aus einem abgebrochenen Versuch von vorletzter Woche
/// stammen — und übernähme sie in ein Schreiben, das hinausgeht.
class EntwurfHinweis extends StatelessWidget {
  final VorgangEntwurf entwurf;
  final VoidCallback onWeiterarbeiten;
  final VoidCallback onVerwerfen;

  const EntwurfHinweis({
    super.key,
    required this.entwurf,
    required this.onWeiterarbeiten,
    required this.onVerwerfen,
  });

  /// Wann der Stand entstand. Von heute reicht die Uhrzeit; alles Ältere trägt
  /// sein Datum, sonst hieße „von 14:32 Uhr" auch bei einem drei Wochen alten
  /// Entwurf, er sei von eben.
  static String beschriftung(DateTime zeitpunkt, DateTime jetzt) {
    final uhrzeit = deutscheUhrzeit(zeitpunkt);
    final vonHeute =
        zeitpunkt.year == jetzt.year &&
        zeitpunkt.month == jetzt.month &&
        zeitpunkt.day == jetzt.day;
    return vonHeute
        ? 'Angefangener Stand von $uhrzeit Uhr'
        : 'Angefangener Stand vom ${GermanDateField.formatDate(zeitpunkt)}, '
              '$uhrzeit Uhr';
  }

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: farben.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_edu_outlined,
                  color: farben.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    beschriftung(entwurf.gespeichertAm, DateTime.now()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: farben.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onVerwerfen,
                  child: const Text('Verwerfen'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onWeiterarbeiten,
                  child: const Text('Weiterarbeiten'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
