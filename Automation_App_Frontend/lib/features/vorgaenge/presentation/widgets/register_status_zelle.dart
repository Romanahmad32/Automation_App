import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/historie_status_chip.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_status_chip.dart';
import 'package:flutter/material.dart';

/// Die Spalte „Status" der Registertabelle.
///
/// Eine historische Zeile trägt dort **nur** „Historie" — so verlangt es §6.2,
/// und mehr steht dort auch nicht: Der Befund-Chip daneben („2 Befunde") machte
/// aus einer Spalte mit einer Aussage eine mit zweien, und die zweite war die
/// unverständlichere. Was an der Zeile auffiel, steht ausführlich im
/// Herkunftskasten des Bearbeiten-Dialogs, den ein Klick auf die Zeile öffnet —
/// dort, wo der Anwalt es ohnehin braucht, um es zu berichtigen.
///
/// Für einen Vorgang der App steht dort sein Status im Lebenszyklus — den trägt
/// die Registerzeile selbst nicht (sie kennt nur „abgeschlossen"), er kommt
/// über [status] aus dem Vorgangsbestand.
class RegisterStatusZelle extends StatelessWidget {
  final RegisterZeile zeile;

  /// Der Status des zugehörigen Vorgangs, sofern bekannt. Null bei einer
  /// historischen Zeile und solange der Vorgangsbestand noch lädt — dann bleibt
  /// die Zelle leer, statt einen Status zu behaupten.
  final VorgangStatus? status;

  const RegisterStatusZelle({super.key, required this.zeile, this.status});

  @override
  Widget build(BuildContext context) {
    if (zeile.istHistorie) return const HistorieStatusChip();
    if (status == null) return const SizedBox.shrink();
    return VorgangStatusChip(status: status!);
  }
}
