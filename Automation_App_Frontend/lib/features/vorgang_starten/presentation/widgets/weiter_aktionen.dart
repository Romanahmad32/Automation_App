import 'package:automation_app/features/vorgaenge/domain/entities/referenz_teile.dart';
import 'package:flutter/material.dart';

/// Panel, das nach dem Speichern eines Vorgangs erscheint (§3): bietet an,
/// mit den gespeicherten Daten direkt weiterzuarbeiten — entweder eine Vorlage
/// auszufüllen oder zum Postfach zu wechseln. Auswahl meldet das Widget über die
/// Callbacks; die Tab-Navigation übernimmt die View.
class WeiterAktionen extends StatelessWidget {
  final String referenz;
  final VoidCallback onVorlageAusfuellen;
  final VoidCallback onZumPostfach;

  const WeiterAktionen({
    super.key,
    required this.referenz,
    required this.onVorlageAusfuellen,
    required this.onZumPostfach,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vorgang ${ReferenzTeile.zeichenAus(referenz)} gespeichert. '
                    'Direkt weiterarbeiten?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Vorlage ausfüllen'),
                  onPressed: onVorlageAusfuellen,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: const Text('Zum Postfach'),
                  onPressed: onZumPostfach,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
