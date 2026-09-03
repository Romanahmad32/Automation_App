import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:flutter/material.dart';

/// Rückfrage, wenn im Fall-Ordner bereits gleichnamige Dateien liegen (§6.1).
///
/// Gefragt wird einmal für das ganze Schreiben, auch wenn Word-Fassung und PDF
/// zusammen abgelegt werden: Es ist eine Entscheidung des Anwalts über ein
/// Dokument, und getrennt beantwortet liefen die Namen der Fassungen
/// auseinander.
///
/// Gibt die gewählte [AblageStrategie] zurück — oder null, wenn der Anwalt
/// abbricht. Bewusst ohne Vorauswahl: „Ersetzen" verwirft ein Dokument, das
/// bereits in der Akte liegt, und darf kein versehentlicher Doppelklick sein.
class AblageKonfliktDialog extends StatelessWidget {
  /// Vollständige Pfade der bereits vorhandenen Dateien.
  final List<String> vorhandenePfade;

  const AblageKonfliktDialog({super.key, required this.vorhandenePfade});

  List<String> get _dateinamen => [
    for (final pfad in vorhandenePfade) pfad.split(RegExp(r'[\\/]')).last,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mehrere = vorhandenePfade.length > 1;

    return AlertDialog(
      icon: const Icon(Icons.file_copy_outlined),
      title: Text(
        mehrere
            ? 'Dateien liegen schon in der Akte'
            : 'Datei liegt schon in der Akte',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'In diesem Fall-Ordner gibt es bereits '
            '„${_dateinamen.join('" und „')}".',
          ),
          const SizedBox(height: 12),
          for (final pfad in vorhandenePfade)
            SelectableText(pfad, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Text(
            mehrere
                ? 'Ersetzen überschreibt die vorhandenen Dateien endgültig. '
                      'Beide behalten legt das neue Schreiben mit angehängter '
                      'Nummer daneben — für alle Fassungen dieselbe.'
                : 'Ersetzen überschreibt die vorhandene Datei endgültig. '
                      'Beide behalten legt das neue Schreiben mit angehängter '
                      'Nummer daneben.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(AblageStrategie.beideBehalten),
          child: const Text('Beide behalten'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(AblageStrategie.ersetzen),
          child: const Text('Ersetzen'),
        ),
      ],
    );
  }
}
