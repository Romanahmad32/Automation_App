import 'dart:math';

import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_drucker_zeile.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_formular.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_vorschau_flaeche.dart';
import 'package:flutter/material.dart';

/// Der Arbeitsteil des Vollmacht-Dialogs vor dem Druck (§4.11, #164): die
/// Felder samt Druckerzeile und daneben die Seitenvorschau — oder, wenn das
/// Fenster dafür zu schmal ist, die Vorschau unter den Feldern.
///
/// Entschieden wird über die Fensterbreite, nicht über einen
/// `LayoutBuilder`: `AlertDialog` legt seinen Inhalt in eine
/// `IntrinsicWidth`, und die kann ein `LayoutBuilder` nicht beantworten.
class VollmachtArbeitsflaeche extends StatelessWidget {
  /// Ab dieser Fensterbreite stehen Felder und Vorschau nebeneinander.
  static const double breitAb = 1100;

  /// Inhaltsbreite des Dialogs: nebeneinander bzw. untereinander.
  static const double breiteNebeneinander = 1040;
  static const double breiteUntereinander = 600;

  static const double _vorschauBreite = 420;
  static const double _vorschauHoeheUntereinander = 520;

  final VollmachtStand stand;

  const VollmachtArbeitsflaeche({super.key, required this.stand});

  /// Ob im aktuellen Fenster Felder und Vorschau nebeneinander passen.
  static bool nebeneinander(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breitAb;

  @override
  Widget build(BuildContext context) {
    final felder = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        VollmachtFormular(stand: stand),
        VollmachtDruckerZeile(drucker: stand.drucker),
        if (stand.phase != VollmachtPhase.eingabe)
          const LinearProgressIndicator(),
      ],
    );
    final vorschau = VollmachtVorschauFlaeche(stand: stand);

    if (!nebeneinander(context)) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            felder,
            SizedBox(height: _vorschauHoeheUntereinander, child: vorschau),
          ],
        ),
      );
    }

    // Titel, Knöpfe und Ränder des Dialogs brauchen gut 200 Pixel; der Rest
    // des Fensters trägt die Seite, höchstens 640 hoch.
    final hoehe = min(640.0, MediaQuery.sizeOf(context).height * 0.62);
    return SizedBox(
      height: hoehe,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: [
          Expanded(child: SingleChildScrollView(child: felder)),
          SizedBox(width: _vorschauBreite, child: vorschau),
        ],
      ),
    );
  }
}
