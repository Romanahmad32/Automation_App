import 'package:automation_app/core/general_classes/euro_format.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart';
import 'package:flutter/material.dart';

/// Vollständige Aufschlüsselung der RVG-Berechnung unterhalb der Tabelle:
/// jeder Rechenschritt mit seiner gesetzlichen Grundlage, damit die Berechnung
/// gegen die amtliche Gebührentabelle (Anlage 2 zu § 13 RVG) geprüft werden
/// kann. Manuell korrigierte Werte sind entsprechend gekennzeichnet.
class RvgDetails extends StatelessWidget {
  final RvgCalculationState rvgState;
  final double zwischensumme;
  final DamageListing? damageListing;

  const RvgDetails({
    super.key,
    required this.rvgState,
    required this.zwischensumme,
    required this.damageListing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (rvgState) {
      case RvgCalculationError(:final message):
        return Text(
          'RVG-Berechnung fehlgeschlagen: $message',
          style: TextStyle(color: theme.colorScheme.error),
        );
      case RvgCalculationLoaded(:final calculation):
        final geschaeftsgebuehrKorrigiert =
            damageListing?.geschaeftsgebuehrOverride != null;
        final auslagenKorrigiert =
            damageListing?.auslagenpauschaleOverride != null;
        final rows = <(String, String, double, bool)>[
          (
            'Gegenstandswert',
            'Summe der Schadenspositionen',
            calculation.gegenstandswert,
            false,
          ),
          (
            'Wertgebühr (1,0)',
            'Anlage 2 zu § 13 RVG (amtliche Gebührentabelle)',
            calculation.wertgebuehr,
            false,
          ),
          (
            'Geschäftsgebühr',
            geschaeftsgebuehrKorrigiert
                ? 'manuell korrigiert — statt '
                      '${euroBetrag(calculation.wertgebuehr)} € '
                      '× ${_satz(calculation.gebuehrensatz)} (Nr. 2300 VV RVG)'
                : 'Wertgebühr × ${_satz(calculation.gebuehrensatz)} (Nr. 2300 VV RVG)',
            calculation.geschaeftsgebuehr,
            geschaeftsgebuehrKorrigiert,
          ),
          (
            'Auslagenpauschale',
            auslagenKorrigiert
                ? 'manuell korrigiert — statt 20 % der Geschäftsgebühr, '
                      'max. 20 € (Nr. 7002 VV RVG)'
                : '20 % der Geschäftsgebühr, max. 20 € (Nr. 7002 VV RVG)',
            calculation.auslagenpauschale,
            auslagenKorrigiert,
          ),
          ('Zwischensumme RA-Kosten (netto)', '', calculation.netto, false),
          if (calculation.umsatzsteuer > 0)
            (
              'Umsatzsteuer (19 %)',
              'Nr. 7008 VV RVG',
              calculation.umsatzsteuer,
              false,
            ),
          ('Anwaltskosten gesamt', '', calculation.brutto, false),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'RVG-Berechnung im Detail',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            for (final (label, basis, value, korrigiert) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label),
                          if (basis.isNotEmpty)
                            Text(
                              basis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: korrigiert
                                    ? theme.colorScheme.tertiary
                                    : theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${euroBetrag(value)} €',
                      style: korrigiert
                          ? TextStyle(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.tertiary,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gesamtforderung (inkl. RA-Kosten)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${euroBetrag(zwischensumme + calculation.brutto)} €',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Referenz: amtliche Gebührentabelle, Anlage 2 zu § 13 RVG '
              '(Stand KostBRÄG 2025, ab 01.06.2025).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  static String _satz(double value) {
    final text = value.toStringAsFixed(2).replaceAll('.', ',');
    return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
  }
}
