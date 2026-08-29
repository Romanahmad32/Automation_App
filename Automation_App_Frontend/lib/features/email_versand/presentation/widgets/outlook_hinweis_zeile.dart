import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:flutter/material.dart';

/// Steht dort, wo sonst ein Outlook-Knopf stünde, und sagt, warum es ihn hier
/// nicht gibt (§4.7).
///
/// Der Knopf wäre nicht kaputt, er täte nur nichts: eine leere Anhangliste,
/// eine leere Signaturliste. Ein Knopf, der wortlos nichts bewirkt, ist die
/// schlechteste Auskunft von allen — schlechter als gar keiner. Deshalb steht
/// hier statt seiner der Grund, und der ganze Satz hängt im Tooltip, damit die
/// Zeile schmal bleibt.
class OutlookHinweisZeile extends StatelessWidget {
  final OutlookStand stand;

  /// Was an dieser Stelle nicht geht — der Anfang des Satzes.
  final String was;

  const OutlookHinweisZeile({
    super.key,
    required this.stand,
    required this.was,
  });

  @override
  Widget build(BuildContext context) {
    if (stand.steuerbar) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Tooltip(
      message: stand.hinweis,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$was — ${stand.kurz}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
