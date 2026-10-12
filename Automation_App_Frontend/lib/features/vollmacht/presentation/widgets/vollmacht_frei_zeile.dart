import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_feld.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand_felder.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_hinweis.dart';
import 'package:material_ui/material_ui.dart';

/// Die Zeile direkt über den Knöpfen (#171): welche Felder auf dem Papier
/// als Schreiblinie frei bleiben, in der Reihenfolge des Formulars und mit
/// den Beschriftungen der Felder.
///
/// Ein Hinweis, keine Sperre — „Drucken" bleibt möglich (§4.11 „vorbelegt,
/// nicht vorgeschrieben"). Sie steht außerhalb der scrollenden Felder, damit
/// der Anwalt sie beim Druck sieht, auch wenn das leere Feld weiter oben aus
/// dem Bild gescrollt ist. Nur in der Eingabe und nur, wenn etwas frei
/// bleibt; sonst nimmt sie keinen Platz.
class VollmachtFreiZeile extends StatelessWidget {
  final VollmachtStand stand;

  const VollmachtFreiZeile({super.key, required this.stand});

  /// Der Satz zu [felder], z. B. „Auf dem Papier frei zum Ausfüllen:
  /// Vorname, Straße und Hausnummer".
  static String satz(List<VollmachtFeld> felder) =>
      'Auf dem Papier frei zum Ausfüllen: '
      '${felder.map((feld) => feld.beschriftung).join(', ')}';

  @override
  Widget build(BuildContext context) {
    if (stand.phase != VollmachtPhase.eingabe) return const SizedBox.shrink();
    final frei = stand.freiBleibendeFelder;
    if (frei.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: VollmachtHinweis(icon: Icons.edit_note, text: satz(frei)),
    );
  }
}
