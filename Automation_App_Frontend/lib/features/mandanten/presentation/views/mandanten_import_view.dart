import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_datei_auswahl.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_eintrag_kachel.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_filter_leiste.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_zusammenfassung.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_fehler.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die drei Bilder des Imports in einer Ansicht: Datei wählen, Vorschau prüfen,
/// Ergebnis lesen. Bewusst eine Seite und kein Assistent mit Schritten — der
/// Bericht bleibt nach dem Übernehmen stehen, und genau ihn will man danach
/// noch einmal durchgehen.
class MandantenImportView extends StatelessWidget {
  final MandantenImportState state;

  const MandantenImportView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bericht = state.bericht;
    if (bericht == null) return _vorDerDatei(context);

    final sichtbar = state.sichtbar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _dateizeile(context),
        if (state.fehler != null) MandantenFehler(message: state.fehler!),
        ImportZusammenfassung(
          bericht: bericht,
          bearbeitet: state.bearbeitetAnzahl,
          kannUebernehmen: state.kannUebernehmen,
          laufend: state.laufend,
        ),
        ImportFilterLeiste(filter: state.filter, zaehler: state.zaehler),
        Text(
          '${sichtbar.length} von ${bericht.eintraege.length} Zeilen in dieser '
          'Ansicht',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Expanded(
          child: sichtbar.isEmpty
              ? MandantenHinweis(_leerText(bericht))
              // ListView.builder, nicht Column: eine Importdatei über den
              // Produktivbestand hat viertausend Zeilen.
              : ListView.builder(
                  itemCount: sichtbar.length,
                  itemBuilder: (_, i) => ImportEintragKachel(
                    befund: sichtbar[i],
                    datensatz: state.eintragAus(sichtbar[i].zeile),
                    bearbeitbar: !state.laufend && !state.uebernommen,
                  ),
                ),
        ),
      ],
    );
  }

  /// Warum die Liste leer ist — „nichts mehr zu prüfen" und „alles weggelassen"
  /// sind sehr verschiedene Nachrichten.
  String _leerText(ImportBericht bericht) => bericht.eintraege.isEmpty
      ? 'Die Datei enthält keinen Mandanten mehr. Über „Andere Datei" lesen '
            'Sie sie im Urzustand neu ein.'
      : 'Keine Zeile passt zu dieser Auswahl. Über „Alle" sehen Sie den '
            'vollständigen Bericht.';

  Widget _vorDerDatei(BuildContext context) {
    if (state.laufend) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            CircularProgressIndicator(),
            Text('Die Datei wird gelesen und geprüft …'),
          ],
        ),
      );
    }

    if (state.fehler != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          MandantenFehler(message: state.fehler!),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.read<MandantenImportCubit>().zuruecksetzen(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Andere Datei wählen'),
            ),
          ),
        ],
      );
    }

    return const ImportDateiAuswahl();
  }

  Widget _dateizeile(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.description_outlined, size: 18, color: theme.hintColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.dateiPfad ?? '',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        TextButton.icon(
          onPressed: () => context.read<MandantenImportCubit>().zuruecksetzen(),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Andere Datei'),
        ),
      ],
    );
  }
}
