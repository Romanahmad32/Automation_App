import 'package:flutter/material.dart';

/// Fragt mit einem `AlertDialog` [abbruch]/[bestaetigung] nach und liefert
/// `true`, wenn zugestimmt wurde — sonst `false` (auch beim Wegtippen neben
/// den Dialog). Deckt die reinen Ja/Nein-Rückfragen ab (Löschen, Verwerfen,
/// Überschreiben); für Dialoge mit Eingabefeldern, Listen oder mehr als zwei
/// Knöpfen bleibt ein eigenes `AlertDialog` nötig.
Future<bool> bestaetigen(
  BuildContext context, {
  required String titel,
  required String text,
  String bestaetigung = 'OK',
  String abbruch = 'Abbrechen',
  bool destruktiv = false,
  IconData? icon,
}) async {
  final ergebnis = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => BestaetigungsDialog(
      titel: titel,
      text: text,
      bestaetigung: bestaetigung,
      abbruch: abbruch,
      destruktiv: destruktiv,
      icon: icon,
    ),
  );
  return ergebnis ?? false;
}

/// Der Dialog hinter [bestaetigen] — als eigenes Widget testbar.
class BestaetigungsDialog extends StatelessWidget {
  final String titel;
  final String text;
  final String bestaetigung;

  /// Beschriftung des ablehnenden Knopfes. „Abbrechen" passt überall dort, wo
  /// die Rückfrage vor einer Handlung steht („Löschen?" → abbrechen heißt: gar
  /// nicht löschen). Beim Verlassen einer Seite mit ungespeicherten Änderungen
  /// stimmt das nicht mehr: Dort ist die Ablehnung selbst eine Handlung
  /// („Weiter bearbeiten"), und „Abbrechen" liesse offen, was abgebrochen wird
  /// — das Verlassen oder das Bearbeiten.
  final String abbruch;

  final bool destruktiv;
  final IconData? icon;

  const BestaetigungsDialog({
    super.key,
    required this.titel,
    required this.text,
    this.bestaetigung = 'OK',
    this.abbruch = 'Abbrechen',
    this.destruktiv = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon, size: 40, color: destruktiv ? scheme.error : null),
      title: Text(titel),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(abbruch),
        ),
        FilledButton(
          style: destruktiv
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(bestaetigung),
        ),
      ],
    );
  }
}
