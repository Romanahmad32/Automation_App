import 'package:flutter/material.dart';

/// Eine Zeile der Versand-Zusammenfassung: links die Beschriftung („An",
/// „Betreff", „Anhänge"), rechts die Werte untereinander.
class EmailZusammenfassungZeile extends StatelessWidget {
  final String beschriftung;
  final List<String> werte;

  const EmailZusammenfassungZeile({
    super.key,
    required this.beschriftung,
    required this.werte,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              beschriftung,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final wert in werte)
                  Text(wert, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
