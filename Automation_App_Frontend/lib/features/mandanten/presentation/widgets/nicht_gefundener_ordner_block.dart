import 'package:flutter/material.dart';

/// Eine Zuordnung, deren Ordner der Scan nicht mehr findet — umbenannt oder
/// verschoben (#132). Steht an der Mandantenkarte unter den gefundenen Akten.
///
/// Ohne diesen Block verschwand eine solche Zuordnung wortlos von der Karte,
/// stand aber weiter in der Datenbank: Der Ordner war dann weder an der Karte
/// noch im Stapel zu sehen, und unter seinem alten Namen blieb er für jeden
/// anderen Mandanten gesperrt.
class NichtGefundenerOrdnerBlock extends StatelessWidget {
  final String ordnername;

  /// Nimmt die Zuordnung zurück; die Rückfrage stellt der Aufrufer.
  final VoidCallback onLoesen;

  const NichtGefundenerOrdnerBlock({
    super.key,
    required this.ordnername,
    required this.onLoesen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.folder_off_outlined, size: 18, color: scheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ordnername,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Nicht im Stammordner gefunden — umbenannt oder verschoben?',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onLoesen,
            icon: const Icon(Icons.link_off, size: 20),
            tooltip: 'Zuordnung lösen',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
