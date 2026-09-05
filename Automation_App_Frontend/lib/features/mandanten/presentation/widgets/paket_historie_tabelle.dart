import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:flutter/material.dart';

/// Die Paket-Historie als kleine Tabelle: welches Paket wann geholt und wann
/// eingelesen wurde.
///
/// Sie beantwortet genau eine Frage, und zwar bevor der Anwalt das nächste
/// Paket holt: **fehlt eines?** Ein Vorgang, der sich über Tage und mehrere
/// Sitzungen zieht, hat sonst keine Stelle, an der auffiele, dass Paket 3 nie
/// zurückkam — ausgelassene Ordner fallen von selbst nirgends auf.
///
/// Deshalb ist eine Zeile ohne „eingelesen" bewusst auffällig gesetzt (gedämpft
/// und mit sichtbarem Strich statt leerer Zelle): Eine leere Zelle liest sich
/// wie ein Darstellungsfehler, ein Strich wie eine Aussage.
class PaketHistorieTabelle extends StatelessWidget {
  /// Die Pakete, neuestes zuerst — so liefert sie der Dienst.
  final List<Arbeitspaket> historie;

  const PaketHistorieTabelle({super.key, required this.historie});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (historie.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Noch kein Arbeitspaket geholt.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wie bei der Registertabelle: mindestens so breit wie der Platz, nach
        // oben offen. Die Seite selbst darf nie waagerecht scrollen.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 24,
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 48,
              headingRowColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHighest,
              ),
              columns: const [
                DataColumn(label: Text('Paket')),
                DataColumn(label: Text('geholt')),
                DataColumn(label: Text('eingelesen')),
                DataColumn(label: Text('Ordner'), numeric: true),
                DataColumn(label: Text('erledigt'), numeric: true),
              ],
              rows: [for (final paket in historie) _zeile(theme, paket)],
            ),
          ),
        );
      },
    );
  }

  DataRow _zeile(ThemeData theme, Arbeitspaket paket) {
    final scheme = theme.colorScheme;
    final stil = paket.eingelesen
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodySmall?.copyWith(color: scheme.outline);

    return DataRow(
      cells: [
        DataCell(Text('${paket.nummer}', style: stil)),
        DataCell(Text(deutschesDatumMitUhrzeit(paket.geholtAm), style: stil)),
        DataCell(
          Text(
            paket.eingelesenAm == null
                ? '–'
                : deutschesDatumMitUhrzeit(paket.eingelesenAm!),
            style: stil,
          ),
        ),
        DataCell(Text('${paket.ordnerAnzahl}', style: stil)),
        DataCell(Text('${paket.erledigtAnzahl}', style: stil)),
      ],
    );
  }
}
