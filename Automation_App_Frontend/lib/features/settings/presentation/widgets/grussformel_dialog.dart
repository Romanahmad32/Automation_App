import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:flutter/material.dart';

/// Anlegen und Ändern eines persönlichen Grußes (§4.7, §7.1).
///
/// Der Dialog **speichert nicht selbst**: Ob der Bestand ihn annimmt (es kann
/// ihn schon geben), weiss erst der Aufrufer — er hält den Dialog offen und
/// zeigt die Meldung, statt den Anwalt vor einer Liste ohne seine Eingabe
/// stehen zu lassen. Dasselbe Muster wie beim `MailVorlageDialog`.
class GrussformelDialog extends StatefulWidget {
  final Grussformel grussformel;

  /// Speichert und meldet, ob es geklappt hat.
  final Future<bool> Function(Grussformel) onSpeichern;

  const GrussformelDialog({
    super.key,
    required this.grussformel,
    required this.onSpeichern,
  });

  @override
  State<GrussformelDialog> createState() => _GrussformelDialogState();
}

class _GrussformelDialogState extends State<GrussformelDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.grussformel.text,
  );

  bool _speichert = false;

  /// Was am Pflichtfeld fehlt; null heisst: nichts. Steht als `errorText` am
  /// Feld — vorher kehrte [_speichern] bei leerer Eingabe wortlos um, und der
  /// Knopf sah kaputt aus (behoben am 03.09.2026).
  String? _fehler;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _fehler = 'Ohne Text gibt es nichts zu speichern.');
      return;
    }

    setState(() {
      _speichert = true;
      _fehler = null;
    });
    final geglueckt = await widget.onSpeichern(
      widget.grussformel.copyWith(text: text),
    );
    if (!mounted) return;
    setState(() => _speichert = false);
    if (geglueckt) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.grussformel.istGespeichert ? 'Gruß ändern' : 'Neuer Gruß',
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _text,
          autofocus: true,
          onSubmitted: (_) => _speichern(),
          onChanged: (_) {
            if (_fehler != null) setState(() => _fehler = null);
          },
          decoration: InputDecoration(
            labelText: 'Gruß *',
            hintText: 'z. B. Salamu aleikum',
            helperText:
                'Steht beim Verfassen zur Auswahl und erscheint unter der '
                'Anrede — ohne Komma, das setzt die Vorlage.',
            helperMaxLines: 3,
            errorText: _fehler,
            border: const OutlineInputBorder(),
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
