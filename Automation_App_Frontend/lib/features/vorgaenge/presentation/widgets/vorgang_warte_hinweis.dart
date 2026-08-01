import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:flutter/material.dart';

/// Ab so vielen Tagen ohne Antwort gilt eine Zentralruf-Anfrage als auffällig
/// lange offen (der Zentralruf antwortet üblicherweise binnen weniger Tage).
const int warteHinweisAbTagen = 7;

/// Hebt Vorgänge hervor, die ungewöhnlich lange auf die Zentralruf-Antwort
/// warten: sichtbar nur im Status „Angefragt" ab [warteHinweisAbTagen] Tagen
/// seit der Anfrage. So gehen Anfragen nicht unter, deren Antwort verloren
/// ging oder die erneut gestellt werden müssen.
class VorgangWarteHinweis extends StatelessWidget {
  final Vorgang vorgang;

  const VorgangWarteHinweis({super.key, required this.vorgang});

  @override
  Widget build(BuildContext context) {
    if (vorgang.status != VorgangStatus.angefragt) {
      return const SizedBox.shrink();
    }
    final tage = DateTime.now().difference(vorgang.angefragtAm).inDays;
    if (tage < warteHinweisAbTagen) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Wartet seit $tage Tagen auf die Zentralruf-Antwort.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
