import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:flutter/material.dart';

/// Ein leer gebliebener Platzhalter, ausgeschrieben: **was fehlt und wo es
/// gepflegt wird** (§4.7, ergänzt am 02.09.2026).
///
/// Vorher stand hier „bleibt leer — die Zeile entfällt" und daneben ein Knopf
/// in den Vorlagentext. Beides wusste der Anwalt schon: Er hat die Vorlage
/// geschrieben. Die Auskunft, die zählt, ist die Fehlstelle — „im
/// Mandantenregister nicht erfasst" gegen „kein Feld dieses Namens" sind zwei
/// völlig verschiedene Aufgaben.
///
/// Im Ton des übrigen Hinweiswesens (`VorgangFehlendeDatenHinweis`):
/// `tertiary`, kein Alarmrot. Ein fehlender Zusatzgruß ist kein Fehler,
/// sondern eine Zeile, die entfällt.
class PlatzhalterFehlstelleZeile extends StatelessWidget {
  final PlatzhalterBefund befund;

  const PlatzhalterFehlstelleZeile({super.key, required this.befund});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = theme.colorScheme.tertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.playlist_add_check_circle_outlined,
              size: 16,
              color: farbe,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name und Stelle in einer Zeile: Der Anwalt sucht die Stelle
                // in seiner Vorlage, und die Zeilennummer führt ihn hin.
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: befund.geschrieben,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: farbe,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' ${befund.stelle}'
                            '${befund.zeileEntfaellt ? ' — entfällt ganz' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  befund.bezeichnung.isEmpty
                      ? befund.fehlstelle
                      : '${befund.bezeichnung}: ${befund.fehlstelle}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
