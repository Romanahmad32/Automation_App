import 'package:automation_app/features/backup/domain/entities/letzte_sicherung.dart';
import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:flutter/material.dart';

/// Meldet, dass die letzte automatische Sicherung misslungen ist (§7.2).
///
/// Sie läuft, wenn das Fenster schon zu ist — der Anwalt kann es also erst hier
/// erfahren, beim nächsten Start. Deshalb steht sie **vor** der Oberfläche und
/// nicht als Hinweiszeile irgendwo darin: Eine Sicherung, von der man annimmt,
/// dass es sie gibt, ist gefährlicher als gar keine.
class SicherungsFehlerKarte extends StatelessWidget {
  final LetzteSicherung lauf;

  const SicherungsFehlerKarte({super.key, required this.lauf});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.report_gmailerrorred_outlined,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Die automatische Sicherung ist fehlgeschlagen',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Beim letzten Beenden ${SicherungsZeitpunkt.beschreibe(lauf.zeitpunkt)} '
            'konnte der Stand nicht abgelegt werden. Er liegt weiter nur auf '
            'diesem Rechner.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          if ((lauf.meldung ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              lauf.meldung!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
