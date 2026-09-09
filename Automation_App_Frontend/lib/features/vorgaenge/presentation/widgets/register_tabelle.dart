import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_jahres_zeile.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_sachverhalt_zelle.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_status_zelle.dart';
import 'package:flutter/material.dart';

/// Das Sachgebiete-Register als Tabelle im verbindlichen Spaltenschema
/// (Lfd. Nr. | Zeichen | Sache · Sachbestand | Rechtsgebiet) — gemeinsam
/// genutzt von der Registerseite und der Startseiten-Karte, damit beide
/// dieselben Spalten und Breiten zeigen.
///
/// Die Zeilen kommen als [RegisterZeile] herein, also fertig gebaut aus dem
/// Backend. Sie können aus einem Vorgang der App stammen oder aus dem
/// übernommenen Registerbuch; historische Zeilen stehen grau, tragen den Chip
/// „Historie" und lassen sich über [onHistorieZeile] berichtigen.
///
/// Die Tabelle füllt immer die verfügbare Breite: die schmalen Spalten nehmen
/// sich, was ihr Inhalt braucht, der übrige Platz geht an die Sache-Spalte. Ist
/// das Fenster zu schmal für den Inhalt, wird waagerecht gescrollt, statt die
/// Spalten unleserlich zu quetschen.
class RegisterTabelle extends StatelessWidget {
  final List<RegisterZeile> zeilen;

  /// Gedrängtere Zeilenhöhen für die Startseiten-Karte.
  final bool kompakt;

  /// Blendet eine fünfte Spalte mit dem Status ein. Nur die Registerseite
  /// braucht sie, seit dort **alle** Zeilen stehen und nicht mehr nur die
  /// abgeschlossenen — ohne sie wäre einer Zeile ohne laufende Nummer nicht
  /// anzusehen, ob sie noch läuft oder ob die Nummer fehlt. In der
  /// Spiegeldatei übernimmt das die Kursivstellung: Dort ist der Satzspiegel
  /// für eine fünfte Spalte zu schmal.
  final bool mitStatus;

  /// Die fett gesetzte Jahresüberschrift vor jedem Jahrgang, wie im
  /// Registerbuch. Die Startseiten-Karte zeigt nur einen Ausschnitt der
  /// letzten Zeilen und schaltet sie ab — dort wäre sie eine Gliederung ohne
  /// Gegliedertes.
  final bool mitJahreszeilen;

  /// Der Lebenszyklus-Status je Vorgangsreferenz. Die Registerzeile selbst
  /// trägt nur „abgeschlossen"; woher der Status kommt, entscheidet die Seite.
  final Map<String, VorgangStatus> statusJeReferenz;

  /// Klick auf eine **historische** Zeile — der Weg zum Bearbeiten-Dialog.
  /// Null macht die Zeilen unklickbar (Startseiten-Karte).
  final ValueChanged<RegisterZeile>? onHistorieZeile;

  /// Klick auf eine Zeile, hinter der ein **Vorgang der App** steht — der Weg
  /// in die Vorgangsverwaltung. Null macht diese Zeilen unklickbar.
  ///
  /// Getrennt von [onHistorieZeile], weil die beiden Herkünfte an verschiedene
  /// Orte führen: Eine historische Zeile lässt sich nur berichtigen, hinter
  /// einer Vorgangszeile steht ein Mandat, das man weiterbearbeitet.
  final ValueChanged<RegisterZeile>? onVorgangZeile;

  /// Ab dieser verfügbaren Breite (logische Pixel, nicht Bildschirmpunkte)
  /// stehen Sache und Sachbestand in einer Zeile nebeneinander statt
  /// untereinander.
  static const double nebeneinanderAb = 1000;

  const RegisterTabelle({
    super.key,
    required this.zeilen,
    this.kompakt = false,
    this.mitStatus = false,
    this.mitJahreszeilen = false,
    this.statusJeReferenz = const {},
    this.onHistorieZeile,
    this.onVorgangZeile,
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
          // Sache-Spalte mit), nach oben offen: reicht der Platz für den
          // Inhalt nicht, wird die Tabelle breiter als das Fenster und
          // waagerecht scrollbar, statt die Spalten zu quetschen.
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 24,
              // Enger als die Vorgabe von `DataTable` (56): Das Register wird
              // überflogen, nicht gelesen — je mehr Zeilen auf den Schirm
              // passen, desto weniger muss gescrollt werden. Die Höchsthöhe
              // bleibt großzügig, damit „Sache" und „Sachbestand" auf schmalen
              // Fenstern zweizeilig stehen können, ohne beschnitten zu werden.
              headingRowHeight: kompakt ? 36 : 40,
              dataRowMinHeight: kompakt ? 32 : 36,
              dataRowMaxHeight: kompakt ? 52 : 60,
              headingRowColor: WidgetStatePropertyAll(
                theme.colorScheme.surfaceContainerHighest,
              ),
              // Ein Klick auf eine historische Zeile öffnet den
              // Bearbeiten-Dialog — das ist keine Mehrfachauswahl, und
              // `DataTable` blendet die Ankreuzspalte sonst allein deshalb ein,
              // weil `onSelectChanged` gesetzt ist. Ihr „alle auswählen" in der
              // Kopfzeile rief den Rückruf für **jede** Zeile auf und legte so
              // einen Dialog über den nächsten.
              showCheckboxColumn: false,
              // Eine dünne Linie zwischen den Spalten: Bei fünf Spalten und
              // langen Rubren war ohne sie nicht zu sehen, wo „Sache" aufhört
              // und „Rechtsgebiet" anfängt. Dasselbe Gitter zieht das
              // Registerbuch der Kanzlei.
              border: TableBorder(
                verticalInside: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              columns: _spalten(nebeneinander),
              rows: _zeilen(theme, nebeneinander),
            ),
          ),
        );
      },
    );
  }

  List<DataColumn> _spalten(bool nebeneinander) => [
    const DataColumn(
      label: Text('Lfd. Nr.'),
      numeric: true,
      columnWidth: IntrinsicColumnWidth(),
    ),
    const DataColumn(
      label: Text('Zeichen'),
      columnWidth: IntrinsicColumnWidth(),
    ),
    // Nimmt den gesamten Platz auf, den die schmalen Spalten übrig lassen.
    // Untereinander unterschreitet die Spalte nie die Breite ihres Inhalts
    // (DataTable bricht Zellentext nicht um) und die Tabelle wird notfalls
    // scrollbar; nebeneinander begrenzt sie sich auf den freien Platz, weil
    // dort die Sache umbrechen darf.
    DataColumn(
      // `Expanded`, weil DataTable das Label als starres Kind in eine eigene
      // Row setzt — ohne das säßen die beiden Überschriften zusammengeschoben
      // links statt über ihren Hälften.
      label: nebeneinander
          ? const Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sache'),
                  SizedBox(width: RegisterSachverhaltZelle.abstand),
                  Text('Sachbestand'),
                ],
              ),
            )
          : const Text('Sache · Sachbestand'),
      columnWidth: nebeneinander
          ? const FlexColumnWidth()
          : const MaxColumnWidth(FlexColumnWidth(), IntrinsicColumnWidth()),
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
  ];

  /// Die Datenzeilen, bei jedem Jahrgangswechsel von einer Jahresüberschrift
  /// unterbrochen — dieselbe Regel wie `RegisterDokument` im Backend
  /// (`letztesJahr` beginnt bei null, der erste Jahrgang bekommt also auch
  /// eine).
  List<DataRow> _zeilen(ThemeData theme, bool nebeneinander) {
    final rows = <DataRow>[];
    String? letztesJahr;

    for (final zeile in zeilen) {
      if (mitJahreszeilen && zeile.jahr != letztesJahr) {
        rows.add(_jahresZeile(theme, zeile.jahr));
        letztesJahr = zeile.jahr;
      }
      rows.add(_datenZeile(theme, zeile, nebeneinander));
    }
    return rows;
  }

  DataRow _jahresZeile(ThemeData theme, String jahr) => DataRow(
    key: ValueKey('jahr-$jahr'),
    color: WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHigh),
    cells: [
      DataCell(RegisterJahresZeile(jahr: jahr)),
      for (var spalte = 1; spalte < (mitStatus ? 5 : 4); spalte++)
        const DataCell(SizedBox.shrink()),
    ],
  );

  DataRow _datenZeile(
    ThemeData theme,
    RegisterZeile zeile,
    bool nebeneinander,
  ) {
    // Historie steht grau: Sie ist Bestand und keine laufende Arbeit — und der
    // Unterschied muss auch dann sichtbar sein, wenn die Statusspalte fehlt.
    final stil = zeile.istHistorie
        ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
        : null;
    final geklickt = zeile.istHistorie ? onHistorieZeile : onVorgangZeile;

    return DataRow(
      onSelectChanged: geklickt == null ? null : (_) => geklickt(zeile),
      cells: [
        DataCell(Text(zeile.laufendeNummer?.toString() ?? '—', style: stil)),
        DataCell(Text(zeile.zeichen, style: stil)),
        DataCell(
          RegisterSachverhaltZelle(
            zeile: zeile,
            nebeneinander: nebeneinander,
            style: stil,
          ),
        ),
        DataCell(Text(zeile.rechtsgebietAnzeige, style: stil)),
        if (mitStatus)
          DataCell(
            RegisterStatusZelle(
              zeile: zeile,
              status: statusJeReferenz[zeile.vorgangReferenz ?? ''],
            ),
          ),
      ],
    );
  }
}
