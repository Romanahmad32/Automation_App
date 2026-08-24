import 'dart:io';

import 'package:flutter/material.dart';

/// Erfolgsanzeige nach erfolgter Akten-Ablage: zeigt die abgelegten Dateien
/// (je nach gewähltem Format die Word-Fassung, das PDF oder beide) und erlaubt,
/// sie im Explorer zu zeigen oder erneut abzulegen.
class AblageErfolgAnzeige extends StatelessWidget {
  final List<String> zielpfade;
  final VoidCallback onErneut;

  const AblageErfolgAnzeige({
    super.key,
    required this.zielpfade,
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
          zielpfade.length > 1
              ? 'In der Akte abgelegt (${zielpfade.length} Dateien):'
              : 'In der Akte abgelegt:',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final pfad in zielpfade)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SelectableText(
              pfad,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: zielpfade.isEmpty
                  ? null
                  : () => _imExplorerZeigen(zielpfade.first),
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
