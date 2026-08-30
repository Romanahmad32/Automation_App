import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:flutter/material.dart';

/// Das „+" unter der Schadensaufstellung: leere Zeile oder eine der
/// Standardpositionen (§4.4).
///
/// Der Grund für das Menü ist die gelöschte Standardposition. Ohne es wäre sie
/// nur durch Abtippen zurückzuholen — und beim Abtippen entsteht genau die
/// Schreibvariante, wegen der die Liste überhaupt festgelegt wurde.
class SchadenspositionHinzufuegenMenue extends StatelessWidget {
  /// Die Standardpositionen, die das Menü anbietet — die in den Einstellungen
  /// konfigurierten, sonst die Vorgabe.
  final List<StandardSchadensposition> standardpositionen;

  /// Liefert die Bezeichnungen, die gerade in der Aufstellung stehen
  /// (getrimmt). Sie stehen abgehakt und unwählbar im Menü: Ohne das wäre der
  /// häufigste Griff — Menü auf, erste Zeile — ein Doppel der Position, die
  /// ohnehin schon dasteht, denn im Normalfall sind alle vorhanden. So
  /// beantwortet das Menü stattdessen die Frage, mit der man es aufklappt:
  /// welche fehlt mir noch.
  ///
  /// Eine Funktion und kein fertiger Satz, weil das Formular sich beim Tippen
  /// in einem Bezeichnungsfeld **nicht** neu aufbaut — es meldet nur nach oben.
  /// Ein beim Aufbau eingesammelter Satz wäre beim Aufklappen also veraltet,
  /// und eine gerade überschriebene Standardposition bliebe abgehakt und
  /// unwählbar.
  final Set<String> Function() vorhandeneBezeichnungen;

  /// Meldet die gewählte Standardposition; **`null` bedeutet leere Zeile**.
  final void Function(StandardSchadensposition? position) onGewaehlt;

  const SchadenspositionHinzufuegenMenue({
    super.key,
    required this.standardpositionen,
    required this.vorhandeneBezeichnungen,
    required this.onGewaehlt,
  });

  @override
  Widget build(BuildContext context) {
    final farbe = Theme.of(context).colorScheme.primary;

    // Über den Index statt über die Position selbst, mit -1 für die leere
    // Zeile: `PopupMenuButton` liest einen `null`-Wert als Abbruch und ruft
    // `onSelected` dann gar nicht erst auf.
    return PopupMenuButton<int>(
      tooltip: 'Position hinzufügen',
      position: PopupMenuPosition.under,
      onSelected: (index) =>
          onGewaehlt(index < 0 ? null : standardpositionen[index]),
      itemBuilder: (context) {
        // Kleingeschrieben verglichen: „unkostenpauschale" ist dieselbe
        // Position. Bliebe der Eintrag dabei wählbar, legte das Menü ein
        // Beinahe-Doppel an — genau die Schreibvariante, gegen die die feste
        // Liste steht.
        final vorhanden = {
          for (final bezeichnung in vorhandeneBezeichnungen())
            bezeichnung.toLowerCase(),
        };
        bool stehtSchonDa(String bezeichnung) =>
            vorhanden.contains(bezeichnung.toLowerCase());

        return [
          const PopupMenuItem(value: -1, child: Text('Leere Position')),
          const PopupMenuDivider(),
          for (final (index, position) in standardpositionen.indexed)
            PopupMenuItem(
              value: index,
              enabled: !stehtSchonDa(position.bezeichnung),
              child: Row(
                children: [
                  Expanded(child: Text(position.bezeichnung)),
                  if (stehtSchonDa(position.bezeichnung)) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, size: 18),
                  ],
                ],
              ),
            ),
        ];
      },
      // Farbe und Schrift von Hand wie bei einem TextButton, denn hier steht
      // keiner mehr: Ein TextButton im `child` finge den Tipp ab, bevor das
      // Menü ihn sähe. Ohne diese beiden Zeilen erbt der Inhalt `onSurface`
      // und die einzige Schaltfläche der Aufstellung sähe aus wie Fließtext.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: farbe),
            const SizedBox(width: 8),
            Text(
              'Position hinzufügen',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: farbe),
            ),
          ],
        ),
      ),
    );
  }
}
