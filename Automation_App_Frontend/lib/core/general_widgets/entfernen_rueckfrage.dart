import 'package:flutter/material.dart';

/// Die Rückfrage vor dem endgültigen Entfernen eines Bestandseintrags.
///
/// **Warum das eine eigene Klasse ist:** Vorlagen, Grüße und Anredeanfänge
/// kommen nicht wieder — sie stehen als Seed in einer Migration, und die läuft
/// genau einmal. Wer den Anfang „Sehr geehrter" mit einem Fehlklick auf das
/// ✕ eines Chips erwischt, ändert stillschweigend die Vorgabeanrede jeder
/// künftigen Mail. Bis zum 03.09.2026 fragte nur die Vorlagenverwaltung nach;
/// die zwei Chipreihen daneben löschten sofort. Gleich unwiederbringliche
/// Daten dürfen nicht verschieden behandelt werden, und drei Abschriften
/// desselben Dialogs wären der zweite Fehler gewesen.
class EntfernenRueckfrage extends StatelessWidget {
  final String titel;
  final String text;

  const EntfernenRueckfrage({
    super.key,
    required this.titel,
    required this.text,
  });

  /// Stellt die Rückfrage und liefert, ob entfernt werden soll. Ein Abbruch
  /// über die Escape-Taste (null) zählt als **nein**.
  static Future<bool> gestellt(
    BuildContext context, {
    required String titel,
    required String text,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => EntfernenRueckfrage(titel: titel, text: text),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(titel),
    content: Text(text),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Entfernen'),
      ),
    ],
  );
}
