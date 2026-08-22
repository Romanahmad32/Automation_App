import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_word_exporter.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Das interne Sachgebiete-Register (§6.2): die abgeschlossenen Vorgänge im
/// exakten Spaltenschema der mehrseitigen Word-Tabelle der Kanzlei —
/// laufende Nr | Aktenzeichen (Abteilung) | Name ./. Gegner + Sachverhalt v.
/// Datum | Rechtsgebiet.
///
/// Zunächst nur als Ansicht: Der Export ins echte Word-Dokument liegt hinter
/// [RegisterWordExporter] und wird aktiviert, sobald die Registervorlage
/// vorliegt.
@RoutePage()
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  /// Abgeschlossene Vorgänge, sortiert nach laufender Nummer (ohne Nummer ans
  /// Ende). Nur abgeschlossene Aufträge stehen im Register.
  List<Vorgang> _registerZeilen(List<Vorgang> vorgaenge) {
    final zeilen = vorgaenge
        .where((v) => v.status == VorgangStatus.versendet)
        .toList();
    zeilen.sort((a, b) {
      final an = a.laufendeNummer;
      final bn = b.laufendeNummer;
      if (an == null && bn == null) return 0;
      if (an == null) return 1;
      if (bn == null) return -1;
      return an.compareTo(bn);
    });
    return zeilen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exporter = getIt<RegisterWordExporter>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Sachgebiete-Register',
          style: theme.textTheme.titleLarge,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: exporter.verfuegbar
                  ? 'Abgeschlossene Vorgänge ins Word-Register exportieren'
                  : 'Der Word-Export wird aktiviert, sobald die '
                        'Registervorlage der Kanzlei vorliegt.',
              child: OutlinedButton.icon(
                onPressed: exporter.verfuegbar ? () {} : null,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Als Word-Register exportieren'),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<VorgangCubit, List<Vorgang>>(
        bloc: getIt<VorgangCubit>(),
        builder: (context, vorgaenge) {
          final zeilen = _registerZeilen(vorgaenge);
          if (zeilen.isEmpty) {
            return _LeerHinweis();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text(
                  '${zeilen.length} abgeschlossene Vorgänge. Neue Zeilen '
                  'entstehen automatisch, sobald ein Vorgang abgeschlossen wird.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 32,
                      headingRowColor: WidgetStatePropertyAll(
                        theme.colorScheme.surfaceContainerHighest,
                      ),
                      columns: const [
                        DataColumn(label: Text('Lfd. Nr.'), numeric: true),
                        DataColumn(label: Text('Aktenzeichen')),
                        DataColumn(label: Text('Name ./. Gegner · Sachverhalt')),
                        DataColumn(label: Text('Rechtsgebiet')),
                      ],
                      rows: [
                        for (final vorgang in zeilen)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(vorgang.laufendeNummer?.toString() ?? '—'),
                              ),
                              DataCell(Text(vorgang.aktenzeichen)),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Text(vorgang.registerSachverhalt),
                                ),
                              ),
                              DataCell(Text(vorgang.rechtsgebiet.displayName)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LeerHinweis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine abgeschlossenen Vorgänge. Sobald ein Vorgang im '
              'Word-Schritt abgeschlossen wird, erscheint er hier als '
              'Registerzeile.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
