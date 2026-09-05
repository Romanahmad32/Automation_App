import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fragt vor dem Holen nach der Paketgröße.
///
/// Ein Paket ist kein technischer Zuschnitt, sondern die Menge, die ein
/// Erzeuger in **einer** Sitzung schafft — und die der Anwalt danach in der
/// Vorschau noch durchsehen kann. Zweihundert Zeilen sind der Unterschied
/// zwischen Durchsehen und Durchscrollen; deshalb steht die Zahl hier zur Wahl
/// und nicht fest im Code.
///
/// Gibt die gewählte Größe zurück oder null bei Abbruch.
class ArbeitspaketDialog extends StatefulWidget {
  /// Wie viele Ordner überhaupt noch offen sind — die Zahl, an der sich die
  /// Paketgröße messen lässt.
  final int offen;

  /// Vorgabe der Paketgröße.
  static const int vorgabe = 200;

  const ArbeitspaketDialog({super.key, required this.offen});

  @override
  State<ArbeitspaketDialog> createState() => ArbeitspaketDialogState();
}

class ArbeitspaketDialogState extends State<ArbeitspaketDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${ArbeitspaketDialog.vorgabe}',
  );

  int? get _anzahl {
    final wert = int.tryParse(_controller.text.trim());
    return (wert == null || wert < 1) ? null : wert;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Arbeitspaket holen'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Die Datei enthält die Anleitung für den Erzeuger, die '
              'ausgewählten Ordner mit Namensvorschlag und Aktentyp sowie die '
              'bekannten Mandanten. Bearbeitet werden darf nur, was darin '
              'steht.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Wie viele Ordner?',
                helperText: '${widget.offen} Ordner sind noch offen',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _anzahl == null
              ? null
              : () => Navigator.of(context).pop(_anzahl),
          child: const Text('Datei speichern'),
        ),
      ],
    );
  }
}
