import 'dart:io';

import 'package:flutter/material.dart';

/// Erfolgsanzeige nach erfolgter Akten-Ablage: zeigt den Zielpfad und erlaubt,
/// die Datei im Explorer zu zeigen oder erneut abzulegen.
class AblageErfolgAnzeige extends StatelessWidget {
  final String zielpfad;
  final VoidCallback onErneut;

  const AblageErfolgAnzeige({
    super.key,
    required this.zielpfad,
    required this.onErneut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'In der Akte abgelegt:',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SelectableText(
          zielpfad,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => _imExplorerZeigen(zielpfad),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Im Explorer zeigen'),
            ),
            TextButton.icon(
              onPressed: onErneut,
              icon: const Icon(Icons.refresh),
              label: const Text('Erneut ablegen'),
            ),
          ],
        ),
      ],
    );
  }

  void _imExplorerZeigen(String pfad) {
    // Markiert die Datei im Windows-Explorer.
    Process.run('explorer', ['/select,', pfad]);
  }
}
