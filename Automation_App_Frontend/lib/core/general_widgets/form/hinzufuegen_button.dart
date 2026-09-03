import 'package:flutter/material.dart';

/// Der Knopf, der einem Bestand einen Eintrag hinzufügt — linksbündig unter
/// dem, was schon da ist.
///
/// Eigener Baustein aus demselben Grund wie `SpeichernButton`: Dieselbe
/// Handlung stand in vier Masken in vier Bauformen da — als `ActionChip`, als
/// `OutlinedButton`, als `TextButton`, als `ElevatedButton`.
///
/// Der Chip war dabei die schlechteste der vier, und zwar nicht aus Geschmack:
/// Er stand **in derselben Reihe** wie die Einträge und trug dieselbe Umrandung
/// wie sie. „+ Anrede hinzufügen" sah damit aus wie eine vierte Anrede — eine
/// Handlung, die sich als Bestand ausgibt. Was etwas tut, muss anders aussehen
/// als das, woran es etwas tut; deshalb ein Knopf mit gefülltem Rahmen, und
/// deshalb steht er unter der Liste statt in ihr.
class HinzufuegenButton extends StatelessWidget {
  /// Was hinzugefügt wird, in der Sprache des Abschnitts — „Anrede
  /// hinzufügen", nicht „Hinzufügen".
  final String beschriftung;

  final VoidCallback? onHinzufuegen;

  const HinzufuegenButton({
    super.key,
    required this.beschriftung,
    required this.onHinzufuegen,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onHinzufuegen,
        icon: const Icon(Icons.add),
        label: Text(beschriftung),
      ),
    );
  }
}
