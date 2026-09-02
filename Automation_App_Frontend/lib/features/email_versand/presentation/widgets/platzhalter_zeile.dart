import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:flutter/material.dart';

/// Ein Platzhalter in der Übersicht: Name, eingesetzter Wert, Herkunft.
///
/// Ein leerer Befund wird **ausgeschrieben**, nicht weggelassen — gerade er
/// erklärt, warum im Text eine Zeile fehlt.
class PlatzhalterZeile extends StatelessWidget {
  final PlatzhalterBefund befund;

  const PlatzhalterZeile({super.key, required this.befund});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gedaempft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              befund.geschrieben,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  befund.istLeer
                      ? 'bleibt leer — die Zeile entfällt'
                      : befund.wert,
                  style: befund.istLeer
                      ? gedaempft?.copyWith(fontStyle: FontStyle.italic)
                      : theme.textTheme.bodySmall,
                ),
                if (befund.herkunft.isNotEmpty)
                  Text(befund.herkunft, style: gedaempft),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
