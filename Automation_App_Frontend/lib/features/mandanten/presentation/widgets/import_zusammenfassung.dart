import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Was die Datei bewirkt, in Zahlen — und der Knopf, der es wahr macht.
///
/// Die Zahl, die zählt, steht dabei vorn: wie viele Akten-Ordner danach einem
/// Mandanten gehören. Alles andere ist Aufschlüsselung. Ein Anwalt, der vor
/// viertausend offenen Ordnern steht, will an dieser Stelle eine Zahl sehen
/// und nicht eine Tabelle deuten.
class ImportZusammenfassung extends StatelessWidget {
  final ImportBericht bericht;

  /// Wie viele Zeilen der Anwalt von Hand berichtigt hat.
  final int bearbeitet;

  final bool kannUebernehmen;
  final bool laufend;

  const ImportZusammenfassung({
    super.key,
    required this.bericht,
    required this.bearbeitet,
    required this.kannUebernehmen,
    required this.laufend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    final fertig = bericht.angewendet;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fertig ? farben.secondaryContainer : farben.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: farben.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fertig ? Icons.check_circle_outline : Icons.preview_outlined,
                color: fertig ? farben.secondary : farben.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fertig ? _fertigText() : _vorschauText(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!fertig) _uebernahmeKnopf(context),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _zahlen(theme)),
        ],
      ),
    );
  }

  String _vorschauText() =>
      '${bericht.ordnerZugeordnet} Ordner bekommen einen Mandanten'
      '${bericht.ohneMandantenbezug > 0 ? ", ${bericht.ohneMandantenbezug} werden als „ohne Mandantenbezug“ vermerkt" : ""}.';

  String _fertigText() =>
      'Übernommen: ${bericht.ordnerZugeordnet} Ordner zugeordnet, '
      '${bericht.neu} Mandanten angelegt.';

  List<Widget> _zahlen(ThemeData theme) => [
    _zahl(theme, 'neu', bericht.neu),
    _zahl(theme, 'ergänzt', bericht.ergaenzt),
    _zahl(theme, 'unverändert', bericht.unveraendert),
    _zahl(theme, 'abgelehnt', bericht.abgelehnt),
    _zahl(theme, 'zu prüfen', bericht.zuPruefen),
    if (bearbeitet > 0) _zahl(theme, 'von Hand geändert', bearbeitet),
  ];

  Widget _zahl(ThemeData theme, String bezeichnung, int wert) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text('$wert $bezeichnung'),
    labelStyle: theme.textTheme.bodySmall,
  );

  Widget _uebernahmeKnopf(BuildContext context) {
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
    final cubit = context.read<MandantenImportCubit>();
    final bestaetigt = await bestaetigen(
      context,
      titel: 'Import übernehmen?',
      text:
          '${bericht.neu} Mandanten werden angelegt, ${bericht.ergaenzt} '
          'ergänzt und ${bericht.ordnerZugeordnet} Ordner zugeordnet.\n\n'
          'Vorhandene Angaben werden dabei nicht überschrieben, nur leere '
          'Felder gefüllt. Abgelehnte Zeilen bleiben liegen.',
      bestaetigung: 'Übernehmen',
    );
    if (!bestaetigt) return;
    await cubit.uebernehmen();
  }
}
