import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_wartezeit.dart';
import 'package:flutter/material.dart';

/// Hebt Vorgänge hervor, die ungewöhnlich lange auf die Zentralruf-Antwort
/// warten: sichtbar nur im Status „Angefragt" ab [warteHinweisAbTagen] Tagen
/// seit der Anfrage. So gehen Anfragen nicht unter, deren Antwort verloren
/// ging oder die erneut gestellt werden müssen.
class VorgangWarteHinweis extends StatelessWidget {
  final Vorgang vorgang;

  const VorgangWarteHinweis({super.key, required this.vorgang});

  @override
  Widget build(BuildContext context) {
    if (!VorgangWartezeit.wartetLange(vorgang)) {
      return const SizedBox.shrink();
    }
    final tage = VorgangWartezeit.tageSeitAnfrage(vorgang);

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
