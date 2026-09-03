import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:flutter/material.dart';

/// Die drei Filter über dem Zuordnungsstapel: Ordnername, Topf und
/// Änderungszeitpunkt. Der Topf-Umschalter nennt jede Zahl, damit der Anwalt
/// sieht, was gerade nicht vor ihm liegt — beiseitegelegt ist nicht gelöscht.
class OrdnerFilterLeiste extends StatelessWidget {
  final ZuordnungFilter filter;

  /// Wie viele Ordner in jedem Topf liegen (Name und Zeitfenster bereits
  /// angewandt).
  final Map<OrdnerAnsicht, int> zaehler;

  final ValueChanged<ZuordnungFilter> onChanged;

  const OrdnerFilterLeiste({
    super.key,
    required this.filter,
    required this.zaehler,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        EntitySearchBar(
          initialQuery: filter.query,
          hintText: 'Ordnernamen durchsuchen …',
          onChanged: (wert) => onChanged(filter.copyWith(query: wert)),
        ),
        // Umbruchfähig statt Row: die Beschriftungen tragen Zahlen, die im
        // Produktivbestand vierstellig werden, und das Fenster ist schmaler
        // als die Summe der Bedienelemente nebeneinander.
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<OrdnerAnsicht>(
              segments: [
                for (final topf in OrdnerAnsicht.values)
                  ButtonSegment(
                    value: topf,
                    label: Text('${topf.bezeichnung} (${zaehler[topf] ?? 0})'),
                  ),
              ],
              selected: {filter.ansicht},
              onSelectionChanged: (auswahl) =>
                  onChanged(filter.copyWith(ansicht: auswahl.first)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                const Text('Geändert:'),
                DropdownButton<GeaendertSeit>(
                  value: filter.geaendertSeit,
                  items: [
                    for (final wert in GeaendertSeit.values)
                      DropdownMenuItem(
                        value: wert,
                        child: Text(wert.bezeichnung),
                      ),
                  ],
                  onChanged: (wert) => wert == null
                      ? null
                      : onChanged(filter.copyWith(geaendertSeit: wert)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
