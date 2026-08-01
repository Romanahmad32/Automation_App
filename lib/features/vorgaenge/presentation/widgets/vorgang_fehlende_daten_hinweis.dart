import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_vollstaendigkeit.dart';
import 'package:flutter/material.dart';

/// Dezenter Hinweis in der Vorgangszeile, welche Daten für das
/// Anspruchsschreiben noch fehlen ([VorgangVollstaendigkeit]) — so pflegt der
/// Anwalt Lücken nach, bevor er im Word-Assistenten vor leeren Feldern steht.
/// Unsichtbar, wenn nichts fehlt.
class VorgangFehlendeDatenHinweis extends StatelessWidget {
  final Vorgang vorgang;

  const VorgangFehlendeDatenHinweis({super.key, required this.vorgang});

  @override
  Widget build(BuildContext context) {
    final fehlt = VorgangVollstaendigkeit.fehlendeDatenFuerSchreiben(vorgang);
    if (fehlt.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final farbe = theme.colorScheme.tertiary;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.playlist_add_check_circle_outlined, size: 16, color: farbe),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Für das Anspruchsschreiben fehlen noch: ${fehlt.join(', ')}.',
              style: theme.textTheme.bodySmall?.copyWith(color: farbe),
            ),
          ),
        ],
      ),
    );
  }
}
