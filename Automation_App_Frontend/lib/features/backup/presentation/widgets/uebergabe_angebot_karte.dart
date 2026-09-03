import 'package:automation_app/features/backup/domain/entities/uebergabe_angebot.dart';
import 'package:automation_app/features/backup/presentation/utils/sicherungs_zeitpunkt.dart';
import 'package:flutter/material.dart';

/// Die Frage, um die es in §7.2 geht: „Zuletzt heute 14:12 auf BUERO-PC
/// gearbeitet. Diesen Stand übernehmen?"
///
/// Daneben steht, wann *dieser* Rechner zuletzt gesichert hat. Das ist kein
/// Beiwerk: Eine Übernahme ersetzt den hiesigen Bestand, und ohne den Vergleich
/// wäre die Frage eine Frage ohne die Hälfte der Antwort. Wer beide Zeitpunkte
/// sieht, erkennt sofort, ob er etwas aufgibt.
class UebergabeAngebotKarte extends StatelessWidget {
  final UebergabeAngebot angebot;

  /// Wann dieser Rechner zuletzt gesichert hat; null heißt: noch nie.
  final DateTime? eigenerStand;

  const UebergabeAngebotKarte({
    super.key,
    required this.angebot,
    this.eigenerStand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zuletzt ${SicherungsZeitpunkt.beschreibe(angebot.zuletztGearbeitet)} '
          'auf ${angebot.rechnername} gearbeitet.',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text('Diesen Stand übernehmen?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        _zeile(
          context,
          Icons.cloud_download_outlined,
          'Dort gesichert',
          SicherungsZeitpunkt.beschreibe(angebot.gesichertAm),
        ),
        const SizedBox(height: 8),
        _zeile(
          context,
          Icons.computer_outlined,
          'Hier gesichert',
          eigenerStand == null
              ? 'noch nie — auf diesem Rechner liegt kein eigener Stand'
              : SicherungsZeitpunkt.beschreibe(eigenerStand!),
        ),
        const SizedBox(height: 16),
        Text(
          'Übernehmen ersetzt die Daten auf diesem Rechner. Der bisherige Stand '
          'wird vorher automatisch als Sicherungskopie abgelegt.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _zeile(BuildContext context, IconData icon, String was, String wann) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Text('$was: ', style: theme.textTheme.bodyMedium),
        Expanded(
          child: Text(
            wann,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
