import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_sachverhalt_zelle.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_status_chip.dart';
import 'package:flutter/material.dart';

/// Das Sachgebiete-Register als Tabelle im verbindlichen Spaltenschema
/// (laufende Nr. | Aktenzeichen | Name ./. Gegner + Sachverhalt | Rechtsgebiet)
/// — gemeinsam genutzt von der Registerseite und der Startseiten-Karte, damit
/// beide dieselben Spalten und Breiten zeigen.
///
/// Die Tabelle füllt immer die verfügbare Breite: die schmalen Spalten nehmen
/// sich, was ihr Inhalt braucht, der übrige Platz geht an die
/// Sachverhalt-Spalte. Ist das Fenster zu schmal für den Inhalt, wird
/// waagerecht gescrollt, statt die Spalten unleserlich zu quetschen.
class RegisterTabelle extends StatelessWidget {
  final List<Vorgang> zeilen;

  /// Gedrängtere Zeilenhöhen für die Startseiten-Karte.
  final bool kompakt;

  /// Blendet eine fünfte Spalte mit dem Vorgangsstatus ein. Nur die
  /// Registerseite braucht sie, seit dort **alle** Vorgänge stehen und nicht
  /// mehr nur die abgeschlossenen — ohne sie wäre einer Zeile ohne laufende
  /// Nummer nicht anzusehen, ob sie noch läuft oder ob die Nummer fehlt.
  /// In der Spiegeldatei übernimmt das die Kursivstellung: Dort ist der
  /// Satzspiegel für eine fünfte Spalte zu schmal.
  final bool mitStatus;

  /// Ab dieser verfügbaren Breite (logische Pixel, nicht Bildschirmpunkte)
  /// stehen Parteien und Sachbestand in einer Zeile nebeneinander statt
  /// untereinander.
  static const double nebeneinanderAb = 1000;

  const RegisterTabelle({
    super.key,
    required this.zeilen,
    this.kompakt = false,
    this.mitStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final nebeneinander = constraints.maxWidth >= nebeneinanderAb;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Mindestens so breit wie der verfügbare Platz (dann wächst die
          // Sachverhalt-Spalte mit), nach oben offen: reicht der Platz für den
          // Inhalt nicht, wird die Tabelle breiter als das Fenster und
          // waagerecht scrollbar, statt die Spalten zu quetschen.
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 24,
              headingRowHeight: kompakt ? 40 : 48,
              dataRowMinHeight: kompakt ? 40 : 48,
              dataRowMaxHeight: kompakt ? 64 : 72,
              headingRowColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest,
              ),
              columns: [
                const DataColumn(
                  label: Text('Lfd. Nr.'),
                  numeric: true,
                  columnWidth: IntrinsicColumnWidth(),
                ),
                const DataColumn(
                  label: Text('Aktenzeichen'),
                  columnWidth: IntrinsicColumnWidth(),
                ),
                // Nimmt den gesamten Platz auf, den die schmalen Spalten übrig
                // lassen. Untereinander unterschreitet die Spalte nie die
                // Breite ihres Inhalts (DataTable bricht Zellentext nicht um)
                // und die Tabelle wird notfalls scrollbar; nebeneinander
                // begrenzt sie sich auf den freien Platz, weil dort die
                // Parteienbezeichnung umbrechen darf.
                DataColumn(
                  // `Expanded`, weil DataTable das Label als starres Kind in
                  // eine eigene Row setzt — ohne das säßen die beiden
                  // Überschriften zusammengeschoben links statt über ihren
                  // Hälften.
                  label: nebeneinander
                      ? const Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Name ./. Gegner'),
                              SizedBox(width: RegisterSachverhaltZelle.abstand),
                              Text('Sachverhalt'),
                            ],
                          ),
                        )
                      : const Text('Name ./. Gegner · Sachverhalt'),
                  columnWidth: nebeneinander
                      ? const FlexColumnWidth()
                      : const MaxColumnWidth(
                          FlexColumnWidth(),
                          IntrinsicColumnWidth(),
                        ),
                ),
                const DataColumn(
                  label: Text('Rechtsgebiet'),
                  columnWidth: IntrinsicColumnWidth(),
                ),
                if (mitStatus)
                  const DataColumn(
                    label: Text('Status'),
                    columnWidth: IntrinsicColumnWidth(),
                  ),
              ],
              rows: [
                for (final vorgang in zeilen)
                  DataRow(
                    cells: [
                      DataCell(Text(vorgang.laufendeNummer?.toString() ?? '—')),
                      DataCell(Text(vorgang.aktenzeichen)),
                      DataCell(
                        RegisterSachverhaltZelle(
                          vorgang: vorgang,
                          nebeneinander: nebeneinander,
                        ),
                      ),
                      DataCell(Text(vorgang.rechtsgebiet.displayName)),
                      if (mitStatus)
                        DataCell(VorgangStatusChip(status: vorgang.status)),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
