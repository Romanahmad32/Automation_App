import 'package:automation_app/core/general_classes/euro_format.dart';
import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/preview_table_cell.dart';
import 'package:flutter/material.dart';

/// Kleine Vorschau in den Einstellungen: So sieht die Schadensaufstellung mit
/// den konfigurierten Standardpositionen aus, wenn eine neue begonnen wird —
/// gleiche Spalten und gleiche Kopfzeile wie die generierte Word-Tabelle und
/// die Live-Vorschau im Wizard (`SchadensaufstellungPreview`). Ohne
/// Zwischensumme und RVG-Zeile: Vorbelegte Beträge sind Vorschläge, keine
/// Forderung.
class StandardpositionenVorschau extends StatelessWidget {
  final List<StandardSchadensposition> positionen;

  /// Konfigurierte Titelzeilen-Farbe aus den Kanzlei-Einstellungen; `null`
  /// fällt auf das Standardgrau des Backends zurück.
  final String? headerColorHex;

  const StandardpositionenVorschau({
    super.key,
    required this.positionen,
    this.headerColorHex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = _parseHex(headerColorHex) ?? const Color(0xFFD9D9D9);
    // Die Farben sind hell, daher in der Kopfzeile dunkle Schrift erzwingen.
    final headerCellStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );
    final bandedColor = headerColor.withValues(alpha: 0.4);

    return Table(
      border: TableBorder.all(color: theme.dividerColor),
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1.2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: headerColor),
          children: [
            PreviewTableCell('Position', style: headerCellStyle),
            PreviewTableCell('Bezeichnung', style: headerCellStyle),
            PreviewTableCell(
              'Forderung in €',
              style: headerCellStyle,
              alignRight: true,
            ),
          ],
        ),
        for (final (index, position) in positionen.indexed)
          TableRow(
            decoration: index.isOdd ? BoxDecoration(color: bandedColor) : null,
            children: [
              PreviewTableCell('${index + 1}'),
              PreviewTableCell(position.bezeichnung),
              PreviewTableCell(
                position.betrag != null ? euroBetrag(position.betrag!) : '',
                alignRight: true,
              ),
            ],
          ),
      ],
    );
  }

  static Color? _parseHex(String? hex) {
    final value = hex?.trim().replaceFirst('#', '') ?? '';
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(0xFF000000 | int.parse(value, radix: 16));
  }
}
