import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_platzhalter.dart';
import 'package:flutter/material.dart';

/// Anlegen und Ändern einer Mail-Textvorlage (§4.7). Liefert beim Speichern
/// die bearbeitete Vorlage zurück; `null` heisst abgebrochen.
///
/// Der Dialog **speichert nicht selbst**: Ob das Backend die Vorlage annimmt
/// (der Name kann vergeben sein), weiss erst der Aufrufer — er hält den Dialog
/// offen und zeigt die Meldung, statt ihn zu schliessen und den Anwalt vor
/// einer Liste ohne seine Eingabe stehen zu lassen.
class MailVorlageDialog extends StatefulWidget {
  final MailVorlage vorlage;

  /// Speichert und meldet, ob es geklappt hat.
  final Future<bool> Function(MailVorlage) onSpeichern;

  const MailVorlageDialog({
    super.key,
    required this.vorlage,
    required this.onSpeichern,
  });

  @override
  State<MailVorlageDialog> createState() => _MailVorlageDialogState();
}

class _MailVorlageDialogState extends State<MailVorlageDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.vorlage.name,
  );
  late final TextEditingController _betreff = TextEditingController(
    text: widget.vorlage.betreff,
  );
  late final TextEditingController _text = TextEditingController(
    text: widget.vorlage.text,
  );

  bool _speichert = false;

  @override
  void dispose() {
    _name.dispose();
    _betreff.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    setState(() => _speichert = true);
    final geglueckt = await widget.onSpeichern(
      widget.vorlage.copyWith(
        name: name,
        betreff: _betreff.text.trim(),
        text: _text.text,
      ),
    );
    if (!mounted) return;
    setState(() => _speichert = false);
    if (geglueckt) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hilfe = MailPlatzhalter.haeufige
        .map((name) => '{{$name}}')
        .join(' · ');

    return AlertDialog(
      title: Text(
        widget.vorlage.istGespeichert ? 'Vorlage ändern' : 'Neue Vorlage',
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  helperText:
                      'Danach wählen Sie die Vorlage beim Verfassen aus.',
                  border: OutlineInputBorder(),
                ),
              ),
              TextField(
                controller: _betreff,
                decoration: const InputDecoration(
                  labelText: 'Betreff',
                  border: OutlineInputBorder(),
                ),
              ),
              TextField(
                controller: _text,
                minLines: 8,
                maxLines: 16,
                decoration: InputDecoration(
                  labelText: 'Nachrichtentext',
                  helperText:
                      'Platzhalter: $hilfe — eine Zeile, in der jeder '
                      'Platzhalter leer bleibt, entfällt ganz. Die Signatur '
                      'nicht mit eintippen, die hängt der Versand an.',
                  helperMaxLines: 4,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _speichert ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _speichert ? null : _speichern,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
