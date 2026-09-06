import 'package:flutter/material.dart';

/// Die Überschrift des Vorlageneditors — „Vorlage bearbeiten" oder „Neue
/// Vorlage erstellen".
///
/// Eigenes Widget, weil die Detailseite mit Stufe 2 an ihrem Zeilenbudget
/// stand und die Zeilen dem gehören sollen, was die Seite wirklich
/// zusammensetzt (#104).
class VorlagenEditorKopf extends StatelessWidget {
  /// true im Bearbeiten-Modus, false beim Anlegen.
  final bool bearbeiten;

  const VorlagenEditorKopf({super.key, required this.bearbeiten});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        bearbeiten ? 'Vorlage bearbeiten' : 'Neue Vorlage erstellen',
        // `headlineSmall` statt `titleLarge` mit fester Größe: Die
        // Seitenüberschrift soll größer sein als ein Sektionstitel, und die
        // passende Rolle dafür wächst mit der Schriftskala mit (Issue #57).
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
