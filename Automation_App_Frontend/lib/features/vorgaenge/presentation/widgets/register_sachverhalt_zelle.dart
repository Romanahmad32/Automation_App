import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';

/// Inhalt der Registerspalte „Name ./. Gegner · Sachverhalt".
///
/// Auf schmalen Fenstern stehen Parteien und Sachbestand untereinander (wie im
/// Word-Register). Ist die Spalte breit genug ([nebeneinander]), rücken sie in
/// eine Zeile — Parteien links, Sachbestand rechtsbündig —, damit die breite
/// Spalte nicht halb leer wirkt.
class RegisterSachverhaltZelle extends StatelessWidget {
  final Vorgang vorgang;

  /// Beide Teile in eine Zeile setzen statt untereinander.
  final bool nebeneinander;

  /// Mindestabstand zwischen Parteien und Sachbestand in der einzeiligen Form.
  static const double abstand = 32;

  const RegisterSachverhaltZelle({
    super.key,
    required this.vorgang,
    required this.nebeneinander,
  });

  @override
  Widget build(BuildContext context) {
    final parteien = vorgang.parteienBezeichnung;
    final sachbestand = vorgang.registerSachbestand;

    // Fehlt einer der beiden Teile, gibt es nichts zu verteilen.
    if (!nebeneinander || parteien.isEmpty || sachbestand == null) {
      return Text(vorgang.registerSachverhalt);
    }

    // Die Parteien nehmen den Platz bis zum Sachbestand ein und dürfen dabei
    // umbrechen: so bleibt der Sachbestand rechtsbündig, und selbst sehr lange
    // Versicherernamen sprengen die Spalte nicht.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(parteien, softWrap: true)),
        const SizedBox(width: abstand),
        Text(sachbestand),
      ],
    );
  }
}
