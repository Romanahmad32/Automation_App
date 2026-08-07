import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/dashboard/domain/services/dashboard_uebersicht.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_karte.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_leer_hinweis.dart';
import 'package:flutter/material.dart';

/// Karte „Sachgebiete-Register": die zuletzt entstandenen Registerzeilen im
/// selben Spaltenschema wie die Registerseite (laufende Nr. | Aktenzeichen |
/// Name ./. Gegner + Sachverhalt | Rechtsgebiet) — der Anwalt sieht auf der
/// Startseite, wo die laufende Auftragsnummer gerade steht.
class DashboardRegisterKarte extends StatelessWidget {
  final DashboardUebersicht uebersicht;

  const DashboardRegisterKarte({super.key, required this.uebersicht});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zeilen = uebersicht.registerZeilen;

    return DashboardKarte(
      titel: 'Register (letzte Zeilen)',
      icon: Icons.table_chart_outlined,
      umfang: zeilen.length < uebersicht.registerGesamt
          ? '${zeilen.length} von ${uebersicht.registerGesamt}'
          : null,
      aktionLabel: 'Zum Register',
      zielTab: AppTabIndex.register,
      child: zeilen.isEmpty
          ? const DashboardLeerHinweis(
              icon: Icons.table_chart_outlined,
              text:
                  'Noch keine abgeschlossenen Vorgänge. Mit dem Abschluss '
                  'eines Vorgangs entsteht hier die nächste Registerzeile.',
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DataTable(
                columnSpacing: 32,
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 64,
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
                        DataCell(Text(vorgang.laufendeNummer?.toString() ?? '—')),
                        DataCell(Text(vorgang.aktenzeichen)),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(vorgang.registerSachverhalt),
                          ),
                        ),
                        DataCell(Text(vorgang.rechtsgebiet.displayName)),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
