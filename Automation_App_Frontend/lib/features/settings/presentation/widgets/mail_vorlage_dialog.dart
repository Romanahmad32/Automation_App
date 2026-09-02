import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagen_hinweise.dart';
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

  /// Je Feld ein Knoten, damit die Auswahl weiss, **wohin** sie einfuegt: Ein
  /// Klick auf einen Chip nimmt dem Textfeld den Fokus, die Schreibmarke im
  /// Controller bleibt aber stehen.
  final FocusNode _betreffFokus = FocusNode();
  final FocusNode _textFokus = FocusNode();

  bool _speichert = false;

  /// Wohin der naechste Platzhalter geht. Vorgabe ist der Nachrichtentext —
  /// dort stehen die meisten, und ein Klick ohne vorherigen Fokus soll nicht
  /// ins Leere gehen.
  bool _zielIstBetreff = false;

  @override
  void initState() {
    super.initState();
    _betreffFokus.addListener(() {
      if (_betreffFokus.hasFocus) _zielIstBetreff = true;
    });
    _textFokus.addListener(() {
      if (_textFokus.hasFocus) _zielIstBetreff = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _betreff.dispose();
    _text.dispose();
    _betreffFokus.dispose();
    _textFokus.dispose();
    super.dispose();
  }

  /// Setzt den Platzhalter an der Schreibmarke ein und gibt den Fokus zurueck —
  /// wer einen Namen einfuegt, schreibt danach weiter.
  void _fuegeEin(String platzhalter) {
    final ziel = _zielIstBetreff ? _betreff : _text;
    final auswahl = ziel.selection;
    final vorhanden = ziel.text;
    // Ohne gueltige Schreibmarke (das Feld war noch nie fokussiert) haengt der
    // Platzhalter hinten an, statt an Position 0 vor den Text zu rutschen.
    final von = auswahl.isValid ? auswahl.start : vorhanden.length;
    final bis = auswahl.isValid ? auswahl.end : vorhanden.length;

    ziel.value = TextEditingValue(
      text: vorhanden.replaceRange(von, bis, platzhalter),
      selection: TextSelection.collapsed(offset: von + platzhalter.length),
    );
    (_zielIstBetreff ? _betreffFokus : _textFokus).requestFocus();
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
                focusNode: _betreffFokus,
                decoration: const InputDecoration(
                  labelText: 'Betreff',
                  border: OutlineInputBorder(),
                ),
              ),
              TextField(
                controller: _text,
                focusNode: _textFokus,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: 'Nachrichtentext',
                  helperText:
                      'Eine Zeile, in der jeder Platzhalter leer bleibt, '
                      'entfällt ganz. Die Signatur nicht mit eintippen, die '
                      'hängt der Versand an.',
                  helperMaxLines: 3,
                  border: OutlineInputBorder(),
                ),
              ),
              // Unter den Feldern und **ueber** der Auswahl: Der Hinweis
              // nennt die Auswahl als Abhilfe, also soll sie darunter
              // stehen und nicht darueber.
              VorlagenHinweise(betreff: _betreff, text: _text),
              PlatzhalterAuswahl(onEinfuegen: _fuegeEin),
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
