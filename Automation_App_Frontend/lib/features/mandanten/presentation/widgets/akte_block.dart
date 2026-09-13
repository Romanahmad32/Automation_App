import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/fall.dart';
import 'package:automation_app/features/mandanten/presentation/utils/akten_ordner_oeffnen.dart';
import 'package:flutter/material.dart';

/// Stellt eine Akte (Ordner) eines Mandanten mit ihren Fällen dar; pro Fall die
/// Anzahl Dokumente in Klammern.
///
/// Akte und Fall öffnen sich im Explorer — die Akte über den Knopf in der
/// Kopfzeile, ein Fall über einen Klick auf seine Zeile (#132). Vorher stand
/// hier nur Text, und wer die Akte sehen wollte, suchte den Ordner selbst.
class AkteBlock extends StatelessWidget {
  final Akte akte;

  /// Nimmt die Zuordnung zurück; die Rückfrage stellt der Aufrufer. `null`
  /// blendet den Knopf aus.
  final VoidCallback? onLoesen;

  const AkteBlock({super.key, required this.akte, this.onLoesen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder, size: 18, color: theme.colorScheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  akte.ordnername,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => AktenOrdnerOeffnen.oeffne(
                  context,
                  pfad: akte.pfad,
                  name: akte.ordnername,
                ),
                icon: const Icon(Icons.folder_open_outlined, size: 20),
                tooltip: 'Akte im Explorer öffnen',
                visualDensity: VisualDensity.compact,
              ),
              if (onLoesen != null)
                IconButton(
                  onPressed: onLoesen,
                  icon: const Icon(Icons.link_off, size: 20),
                  tooltip: 'Zuordnung lösen',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (!akte.faelleGeladen)
            _hinweis(theme, 'Fälle werden gelesen …')
          else if (akte.faelle.isEmpty)
            _hinweis(theme, 'Keine Fälle in diesem Ordner.')
          else
            for (final fall in akte.faelle) _fallZeile(context, theme, fall),
        ],
      ),
    );
  }

  Widget _hinweis(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(left: 24, top: 2),
    child: Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    ),
  );

  /// Die ganze Zeile ist die Tippfläche: Ein eigener Knopf je Fall stünde bei
  /// einer Akte mit zehn Fällen als Spalte gleicher Symbole neben dem Text.
  Widget _fallZeile(BuildContext context, ThemeData theme, Fall fall) =>
      Tooltip(
        message: 'Fall im Explorer öffnen',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => AktenOrdnerOeffnen.oeffne(
            context,
            pfad: fall.pfad,
            name: fall.name,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 2, 4, 2),
            child: Text(
              '• ${fall.name}'
              '${fall.dokumente.isEmpty ? '' : '  (${fall.dokumente.length})'}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      );
}
