import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:flutter/material.dart';

/// Die Paket-Historie als Tabelle: Nr. · geholt am · eingelesen · Ordner ·
/// Zeilen. Nachgebaut nach dem Muster von `RegisterTabelle`
/// (`LayoutBuilder` → waagerecht scrollbar → `DataTable`) — bewusst nicht
/// generalisiert, `RegisterTabelle` ist `Vorgang`-spezifisch.
///
/// Das offene Paket sticht dreifach hervor: getönte Zeile, Nummer und
/// Fortschritt im Akzent, der Fortschrittsbalken auf dem tatsächlichen Stand.
/// Fertige Pakete zeigen denselben Balken voll und grau — gleiche Form,
/// andere Aussage. „–" ersetzt leere Zellen, solange ein Paket offen ist.
class PaketHistorieTabelle extends StatelessWidget {
  final List<ImportPaket> pakete;

  const PaketHistorieTabelle({super.key, required this.pakete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            columnSpacing: 24,
            headingRowHeight: 36,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            headingRowColor: WidgetStatePropertyAll(
              theme.colorScheme.surfaceContainerHighest,
            ),
            columns: const [
              DataColumn(
                label: Text('Nr.'),
                numeric: true,
                columnWidth: IntrinsicColumnWidth(),
              ),
              DataColumn(
                label: Text('geholt am'),
                columnWidth: IntrinsicColumnWidth(),
              ),
              DataColumn(
                label: Text('eingelesen'),
                columnWidth: IntrinsicColumnWidth(),
              ),
              DataColumn(label: Text('Ordner'), columnWidth: FlexColumnWidth()),
              DataColumn(
                label: Text('Zeilen'),
                numeric: true,
                columnWidth: IntrinsicColumnWidth(),
              ),
            ],
            rows: [for (final paket in pakete) _zeile(theme, paket)],
          ),
        ),
      ),
    );
  }

  DataRow _zeile(ThemeData theme, ImportPaket paket) {
    final scheme = theme.colorScheme;
    final offen = paket.offen;
    final ton = offen ? SoftTone.fromAccent(scheme.tertiary, scheme) : null;
    final akzent = offen
        ? theme.textTheme.bodyLarge?.copyWith(
            color: scheme.tertiary,
            fontWeight: FontWeight.w600,
          )
        : theme.textTheme.bodyLarge;
    final fortschritt = paket.anzahlOrdner == 0
        ? 0.0
        : paket.erledigt / paket.anzahlOrdner;

    return DataRow(
      color: ton == null ? null : WidgetStatePropertyAll(ton.background),
      cells: [
        DataCell(Text('${paket.nummer}', style: akzent)),
        DataCell(Text(deutschesDatum(paket.geholtAm.toLocal()))),
        DataCell(
          Text(
            paket.eingelesenAm == null
                ? '–'
                : deutschesDatum(paket.eingelesenAm!.toLocal()),
          ),
        ),
        DataCell(
          // Flexible statt fester Breiten: die „Ordner"-Spalte ist die
          // einzige mit `FlexColumnWidth` und kann schmal werden, wenn das
          // Fenster es ist — der Balken darf schrumpfen, der Text ellipsiert,
          // aber nichts überläuft.
          Row(
            children: [
              Flexible(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fortschritt,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: offen ? scheme.tertiary : scheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                flex: 3,
                child: Text(
                  '${paket.erledigt} von ${paket.anzahlOrdner}',
                  style: akzent,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        DataCell(Text(paket.zeilen == null ? '–' : '${paket.zeilen}')),
      ],
    );
  }
}
