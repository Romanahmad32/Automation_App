import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:flutter/material.dart';

/// Rückfrage, wenn im Fall-Ordner bereits eine gleichnamige Datei liegt (§6.1).
///
/// Gibt die gewählte [AblageStrategie] zurück — oder null, wenn der Anwalt
/// abbricht. Bewusst ohne Vorauswahl: „Ersetzen" verwirft ein Dokument, das
/// bereits in der Akte liegt, und darf kein versehentlicher Doppelklick sein.
class AblageKonfliktDialog extends StatelessWidget {
  /// Vollständiger Pfad der bereits vorhandenen Datei.
  final String vorhandenerPfad;

  const AblageKonfliktDialog({super.key, required this.vorhandenerPfad});

  String get _dateiname => vorhandenerPfad.split(RegExp(r'[\/]')).last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.file_copy_outlined),
      title: const Text('Datei liegt schon in der Akte'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('In diesem Fall-Ordner gibt es bereits „$_dateiname".'),
          const SizedBox(height: 12),
          SelectableText(vorhandenerPfad, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Text(
            'Ersetzen überschreibt die vorhandene Datei endgültig. '
            'Beide behalten legt das neue Schreiben unter „$_dateiname" mit '
            'angehängter Nummer daneben.',
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
