import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_hinweis.dart';
import 'package:flutter/material.dart';

/// Was der Dialog zeigt, nachdem die Vollmacht in Word geöffnet wurde —
/// gewollt („In Word öffnen") oder als Rückfall nach einem gescheiterten
/// Druck (§4.11). Die App weiß danach nicht, ob Papier herauskam; deshalb die
/// Frage, statt still zu vermerken. Die Knöpfe dazu sitzen im Dialog.
class VollmachtWordAnsicht extends StatelessWidget {
  final VollmachtStand stand;

  const VollmachtWordAnsicht({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pfad = stand.pfad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Text(
          stand.geoeffnet
              ? 'Die Vollmacht ist in Word geöffnet. Drucken Sie sie dort aus.'
              : 'Die Vollmacht ist ausgefüllt, ließ sich aber nicht in Word '
                    'öffnen.',
          style: theme.textTheme.bodyLarge,
        ),
        if (pfad != null)
          VollmachtHinweis(
            icon: Icons.description_outlined,
            text: pfad,
            aktionen: [
              TextButton(
                onPressed: () => DateiOeffner.zeigeImOrdner(pfad),
                child: const Text('Im Explorer zeigen'),
              ),
            ],
          ),
        if (stand.warnungen.isNotEmpty)
          VollmachtHinweis(
            icon: Icons.warning_amber_outlined,
            text:
                'In der Vorlage stehen Platzhalter, die die App nicht kennt: '
                '${stand.warnungen.map((w) => '{{$w}}').join(', ')}.',
          ),
        Text(
          'Ist sie gedruckt? Dann vermerken Sie es am Vorgang.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
