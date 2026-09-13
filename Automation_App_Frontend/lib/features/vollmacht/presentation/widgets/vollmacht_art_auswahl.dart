import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:flutter/material.dart';

/// Die drei Vorlagenarten als Umschalter (§4.11). Leer, solange sich aus dem
/// Rechtsgebiet keine Art ableiten ließ — dann sagt die Zeile darunter, dass
/// der Anwalt wählen muss.
class VollmachtArtAuswahl extends StatelessWidget {
  final VollmachtArt? art;
  final String rechtsgebiet;
  final ValueChanged<VollmachtArt>? onGewaehlt;

  const VollmachtArtAuswahl({
    super.key,
    required this.art,
    required this.rechtsgebiet,
    required this.onGewaehlt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gewaehlt = art;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        SegmentedButton<VollmachtArt>(
          segments: [
            for (final eintrag in VollmachtArt.values)
              ButtonSegment(value: eintrag, label: Text(eintrag.titel)),
          ],
          selected: {?gewaehlt},
          emptySelectionAllowed: true,
          onSelectionChanged: onGewaehlt == null
              ? null
              : (auswahl) {
                  if (auswahl.isNotEmpty) onGewaehlt!(auswahl.first);
                },
        ),
        if (gewaehlt == null)
          Text(
            rechtsgebiet.trim().isEmpty
                ? 'Am Vorgang ist kein Rechtsgebiet erfasst — bitte die '
                      'Vorlage wählen.'
                : 'Das Rechtsgebiet „${rechtsgebiet.trim()}“ legt keine '
                      'Vorlage fest — bitte wählen.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
      ],
    );
  }
}
