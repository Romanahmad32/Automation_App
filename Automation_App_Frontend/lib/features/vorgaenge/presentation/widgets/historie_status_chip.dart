import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:flutter/material.dart';

/// Der Status einer übernommenen Registerzeile: **immer** „Historie".
///
/// Er steht an jeder historischen Zeile, nicht nur an den auffälligen. Ohne ihn
/// wäre am Bildschirm nicht zu erkennen, ob eine Zeile aus dem alten
/// Registerbuch stammt oder aus einem Vorgang der App — und der Unterschied
/// zählt: Eine historische Zeile lässt sich nicht öffnen, nur berichtigen, und
/// hinter ihr steht kein Mandat in Bearbeitung.
///
/// Neutrale Farbe mit Absicht: „Historie" ist kein Fortschritt im Lebenszyklus
/// und soll neben den farbigen Vorgangsstatus nicht wie einer aussehen.
class HistorieStatusChip extends StatelessWidget {
  const HistorieStatusChip({super.key});

  @override
  Widget build(BuildContext context) => StatusPille(
    text: 'Historie',
    farbe: Theme.of(context).colorScheme.outline,
    tooltip:
        'Aus dem übernommenen Registerbuch der Kanzlei — kein Vorgang der App.',
  );
}
