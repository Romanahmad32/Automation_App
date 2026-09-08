import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/historie_status_chip.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_befund_chip.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_status_chip.dart';
import 'package:flutter/material.dart';

/// Die Spalte „Status" der Registertabelle.
///
/// Historische Zeilen tragen immer „Historie", auffällige zusätzlich einen
/// Befund-Chip. Für einen Vorgang der App steht dort sein Status im
/// Lebenszyklus — den trägt die Registerzeile selbst nicht (sie kennt nur
/// „abgeschlossen"), er kommt über [status] aus dem Vorgangsbestand.
class RegisterStatusZelle extends StatelessWidget {
  final RegisterZeile zeile;

  /// Der Status des zugehörigen Vorgangs, sofern bekannt. Null bei einer
  /// historischen Zeile und solange der Vorgangsbestand noch lädt — dann bleibt
  /// die Zelle leer, statt einen Status zu behaupten.
  final VorgangStatus? status;

  const RegisterStatusZelle({super.key, required this.zeile, this.status});

  @override
  Widget build(BuildContext context) {
    if (zeile.istHistorie) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const HistorieStatusChip(),
          if (zeile.zuPruefen) RegisterBefundChip(zeile: zeile),
        ],
      );
    }
    if (status == null) return const SizedBox.shrink();
    return VorgangStatusChip(status: status!);
  }
}
