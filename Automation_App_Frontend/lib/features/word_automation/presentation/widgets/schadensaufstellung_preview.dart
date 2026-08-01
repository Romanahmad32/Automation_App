import 'package:automation_app/core/general_classes/euro_format.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/preview_table_cell.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/rvg_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Live-Vorschau der Schadensaufstellung im Dokument-Look: Positionen,
/// Zwischensumme (lokal summiert) und die vom Backend berechneten
/// RVG-Anwaltskosten. Spiegelt das Layout der generierten Word-Tabelle wider.
class SchadensaufstellungPreview extends StatelessWidget {
  final DamageListing? damageListing;

  const SchadensaufstellungPreview({super.key, required this.damageListing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rvgState = context.watch<RvgCalculationBloc>().state;

    final items = damageListing?.items ?? const <DamageItem>[];
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Noch keine vollständige Schadensposition erfasst.\n'
          'Bezeichnung und Betrag eingeben, um die Vorschau zu sehen.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final zwischensumme = items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    final headerStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.bold,
    );
    // Konfigurierte Titelzeilen-Farbe (aus den Einstellungen); Fallback ist das
    // Standardgrau des Backends, damit die Vorschau dem Dokument entspricht.
    // Die Farben sind hell, daher in der Kopfzeile dunkle Schrift erzwingen.
    final headerColor =
        _parseHex(damageListing?.headerColorHex) ?? const Color(0xFFD9D9D9);
    final headerCellStyle = headerStyle?.copyWith(color: Colors.black87);
    final bandedColor = headerColor.withValues(alpha: 0.4);
    final thickLine = BorderSide(color: theme.colorScheme.onSurface, width: 2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Table(
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
              for (final (index, item) in items.indexed)
                TableRow(
                  decoration: index.isOdd
                      ? BoxDecoration(color: bandedColor)
                      : null,
                  children: [
                    PreviewTableCell('${index + 1}'),
                    PreviewTableCell(item.description),
                    PreviewTableCell(euroBetrag(item.amount), alignRight: true),
                  ],
                ),
              // Leerzeile wie im generierten Dokument.
              const TableRow(
                children: [
                  PreviewTableCell(''),
                  PreviewTableCell(''),
                  PreviewTableCell(''),
                ],
              ),
              TableRow(
                decoration: BoxDecoration(
                  border: Border(top: thickLine, bottom: thickLine),
                ),
                children: [
                  PreviewTableCell(''),
                  PreviewTableCell(
                    'Zwischensumme (ohne RA-Kosten)',
                    style: headerStyle,
                  ),
                  PreviewTableCell(
                    euroBetrag(zwischensumme),
                    style: headerStyle,
                    alignRight: true,
                  ),
                ],
              ),
              TableRow(
                children: [
                  const PreviewTableCell(''),
                  const PreviewTableCell('Anwaltskosten nach RVG'),
                  _rvgBruttoCell(rvgState),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          RvgDetails(
            rvgState: rvgState,
            zwischensumme: zwischensumme,
            damageListing: damageListing,
          ),
        ],
      ),
    );
  }

  static Color? _parseHex(String? hex) {
    final value = hex?.trim().replaceFirst('#', '') ?? '';
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(0xFF000000 | int.parse(value, radix: 16));
  }

  Widget _rvgBruttoCell(RvgCalculationState rvgState) {
    return switch (rvgState) {
      RvgCalculationLoaded(:final calculation) => PreviewTableCell(
        euroBetrag(calculation.brutto),
        alignRight: true,
      ),
      RvgCalculationLoading() => const Padding(
        padding: EdgeInsets.all(8),
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      RvgCalculationError() => const PreviewTableCell('—', alignRight: true),
      RvgCalculationInitial() => const PreviewTableCell('…', alignRight: true),
    };
  }
}
