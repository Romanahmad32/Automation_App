import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:flutter/material.dart';

/// Inhalt der Registerspalte „Sache · Sachbestand".
///
/// Die Spalte heißt „Sache" und nicht mehr nach der Zivilsachen-Form allein:
/// Der Bestand kennt zwei Formen — „Mandant ./. Gegner" in Zivilsachen und
/// „Bußgeldsache Mandant" dort, wo es gar keine Gegenseite gibt. Dieselbe
/// Überschrift steht im Word-/PDF-Spiegel (`RegisterLayout` im Backend).
///
/// Auf schmalen Fenstern stehen beide Teile untereinander (wie im
/// Word-Register). Ist die Spalte breit genug ([nebeneinander]), rücken sie in
/// eine Zeile — Sache links, Sachbestand rechtsbündig —, damit die breite
/// Spalte nicht halb leer wirkt.
class RegisterSachverhaltZelle extends StatelessWidget {
  final RegisterZeile zeile;

  /// Beide Teile in eine Zeile setzen statt untereinander.
  final bool nebeneinander;

  /// Schriftstil der Zelle — grau bei historischen Zeilen. Null heißt: der
  /// Stil der Tabelle.
  final TextStyle? style;

  /// Mindestabstand zwischen Sache und Sachbestand in der einzeiligen Form.
  static const double abstand = 32;

  const RegisterSachverhaltZelle({
    super.key,
    required this.zeile,
    required this.nebeneinander,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final parteien = zeile.parteien;
    final sachbestand = zeile.sachbestand;

    // Fehlt einer der beiden Teile, gibt es nichts zu verteilen.
    if (!nebeneinander || parteien.isEmpty || sachbestand.isEmpty) {
      return Text(zeile.sacheUndSachbestand, style: style);
    }

    // Die Sache nimmt den Platz bis zum Sachbestand ein und darf dabei
    // umbrechen: so bleibt der Sachbestand rechtsbündig, und selbst sehr lange
    // Versicherernamen sprengen die Spalte nicht.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(parteien, softWrap: true, style: style)),
        const SizedBox(width: abstand),
        Text(sachbestand, style: style),
      ],
    );
  }
}
