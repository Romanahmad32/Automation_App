import 'package:flutter/material.dart';

/// Benennt einen Anhang für die Mail um (§4.7). Die Datei in der Akte behält
/// ihren Namen — geändert wird nur, was beim Empfänger ankommt.
///
/// Das ist der Regelfall und nicht die Ausnahme: Was aus einer Kamera oder
/// einem Scanner kommt, heißt „IMG_2481.jpg" oder „Dokument1.pdf". Bei der
/// gegnerischen Versicherung landet das in einer Akte mit hunderten Anhängen.
class AnhangUmbenennenDialog extends StatefulWidget {
  /// Der Name, unter dem der Anhang derzeit hinausginge.
  final String name;

  const AnhangUmbenennenDialog({super.key, required this.name});

  /// Liefert den neuen Namen, oder null bei Abbruch.
  static Future<String?> zeigen(BuildContext context, String name) {
    return showDialog<String>(
      context: context,
      builder: (_) => AnhangUmbenennenDialog(name: name),
    );
  }

  @override
  State<AnhangUmbenennenDialog> createState() => _AnhangUmbenennenDialogState();
}

class _AnhangUmbenennenDialogState extends State<AnhangUmbenennenDialog> {
  late final TextEditingController _eingabe = TextEditingController(
    text: widget.name,
  );

  @override
  void initState() {
    super.initState();
    // Nur den Namen vorwählen, nicht die Endung: Wer sie versehentlich
    // überschreibt, verschickt eine Datei, die beim Empfänger kein Programm
    // mehr öffnet.
    final punkt = widget.name.lastIndexOf('.');
    _eingabe.selection = TextSelection(
      baseOffset: 0,
      extentOffset: punkt > 0 ? punkt : widget.name.length,
    );
  }

  @override
  void dispose() {
    _eingabe.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    final neu = _eingabe.text.trim();
    if (neu.isEmpty) return;
    Navigator.pop(context, neu);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Anhang umbenennen'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _eingabe,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Dateiname für die Mail',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _uebernehmen(),
            ),
            const SizedBox(height: 10),
            Text(
              'Die Datei in der Akte behält ihren Namen. Geändert wird nur, '
              'unter welchem Namen der Anhang beim Empfänger ankommt.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _uebernehmen, child: const Text('Übernehmen')),
      ],
    );
  }
}
