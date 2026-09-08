import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/presentation/blocs/register_import_cubit/register_import_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Was ein Jahrgang der Datei bewirkt, in Zahlen — und der Knopf, der es wahr
/// macht (§6.2).
///
/// Die Lücken stehen mit ihren Nummern da und nicht nur als Anzahl: „3 Lücken"
/// ist eine Zahl, „fehlt: 47, 48, 112" ist ein Auftrag. Genau diese Nummern
/// sucht der Anwalt danach im Word-Register nach — sie sind die einzige Probe
/// darauf, dass dem Erzeuger keine Zeile abhandengekommen ist.
class JahrgangBefundKarte extends StatelessWidget {
  final JahrgangBefund befund;

  /// Schon geschrieben — dann sagt die Karte das Ergebnis, statt es noch
  /// einmal anzubieten.
  final bool uebernommen;

  final bool kannUebernehmen;
  final bool laufend;

  const JahrgangBefundKarte({
    super.key,
    required this.befund,
    this.uebernommen = false,
    this.kannUebernehmen = false,
    this.laufend = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              children: [
                Icon(
                  uebernommen
                      ? Icons.check_circle_outline
                      : Icons.calendar_month_outlined,
                  color: uebernommen
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jahrgang ${befund.jahrgang} — ${befund.zeilen} Zeilen',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _knopf(context),
              ],
            ),
            Wrap(spacing: 8, runSpacing: 8, children: _chips(theme)),
            if (befund.luecken.isNotEmpty)
              Text(
                'Fehlende Nummern: ${befund.luecken.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            if (befund.doppelte.isNotEmpty)
              Text(
                'Doppelt vergebene Nummern: ${befund.doppelte.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _chips(ThemeData theme) => [
    if (befund.zuPruefen > 0)
      Chip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(
          Icons.fact_check_outlined,
          size: 16,
          color: theme.colorScheme.onTertiaryContainer,
        ),
        backgroundColor: theme.colorScheme.tertiaryContainer,
        label: Text('${befund.zuPruefen} zu prüfen'),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    _zahl(theme, 'Lücken', befund.luecken.length),
    _zahl(theme, 'doppelt', befund.doppelte.length),
    _zahl(theme, 'Abteilung ≠ Rechtsgebiet', befund.abweichungen),
    _zahl(theme, 'neu', befund.neu),
    _zahl(theme, 'unverändert', befund.unveraendert),
    _zahl(theme, 'abgelehnt', befund.abgelehnt),
  ];

  Widget _zahl(ThemeData theme, String bezeichnung, int wert) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text('$wert $bezeichnung'),
    labelStyle: theme.textTheme.bodySmall,
  );

  Widget _knopf(BuildContext context) {
    if (uebernommen) {
      return Text(
        'übernommen',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
    if (laufend) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: kannUebernehmen ? () => _fragen(context) : null,
      icon: const Icon(Icons.download_done_outlined, size: 18),
      label: const Text('Übernehmen'),
    );
  }

  Future<void> _fragen(BuildContext context) async {
    final cubit = context.read<RegisterImportCubit>();
    final bestaetigt = await bestaetigen(
      context,
      titel: 'Jahrgang ${befund.jahrgang} übernehmen?',
      text:
          '${befund.neu} Zeilen werden in die Registerhistorie geschrieben, '
          '${befund.unveraendert} stehen schon darin und bleiben unangetastet.'
          '${befund.luecken.isEmpty ? '' : '\n\nEs fehlen noch die Nummern '
                    '${befund.luecken.join(', ')}. Sie lassen sich später '
                    'nachtragen.'}',
      bestaetigung: 'Übernehmen',
    );
    if (!bestaetigt) return;
    await cubit.uebernehmen(jahrgang: befund.jahrgang);
  }
}
