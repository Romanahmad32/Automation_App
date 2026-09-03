import 'package:flutter/material.dart';

/// Fragt mit einem `AlertDialog` „Abbrechen"/[bestaetigung] nach und liefert
/// `true`, wenn zugestimmt wurde — sonst `false` (auch beim Wegtippen neben
/// den Dialog). Deckt die reinen Ja/Nein-Rückfragen ab (Löschen, Verwerfen,
/// Überschreiben); für Dialoge mit Eingabefeldern, Listen oder mehr als zwei
/// Knöpfen bleibt ein eigenes `AlertDialog` nötig.
Future<bool> bestaetigen(
  BuildContext context, {
  required String titel,
  required String text,
  String bestaetigung = 'OK',
  bool destruktiv = false,
  IconData? icon,
}) async {
  final ergebnis = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => BestaetigungsDialog(
      titel: titel,
      text: text,
      bestaetigung: bestaetigung,
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
  final bool destruktiv;
  final IconData? icon;

  const BestaetigungsDialog({
    super.key,
    required this.titel,
    required this.text,
    this.bestaetigung = 'OK',
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
          child: const Text('Abbrechen'),
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
