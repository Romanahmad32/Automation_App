import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:flutter/material.dart';

/// Anlegen und Ändern eines Anredeanfangs (§4.7, §7.1).
///
/// Drei Felder, weil das Deutsche hier beugt: „Sehr geehrt**er** Herr" gegen
/// „Sehr geehrt**e** Frau". Wer „Guten Tag" anlegt, schreibt dreimal dasselbe
/// — das ist kein Sonderfall, sondern die Antwort auf eine Frage, die die App
/// nicht erraten darf.
///
/// Der Dialog **speichert nicht selbst**: Ob der Bestand ihn annimmt (es kann
/// ihn schon geben), weiss erst der Aufrufer — er hält den Dialog offen und
/// zeigt die Meldung. Dasselbe Muster wie beim `GrussformelDialog`.
class AnredebausteinDialog extends StatefulWidget {
  final Anredebaustein baustein;

  /// Speichert und meldet, ob es geklappt hat.
  final Future<bool> Function(Anredebaustein) onSpeichern;

  const AnredebausteinDialog({
    super.key,
    required this.baustein,
    required this.onSpeichern,
  });

  @override
  State<AnredebausteinDialog> createState() => _AnredebausteinDialogState();
}

class _AnredebausteinDialogState extends State<AnredebausteinDialog> {
  late final TextEditingController _maennlich = TextEditingController(
    text: widget.baustein.maennlich,
  );
  late final TextEditingController _weiblich = TextEditingController(
    text: widget.baustein.weiblich,
  );
  late final TextEditingController _neutral = TextEditingController(
    text: widget.baustein.neutral,
  );

  bool _speichert = false;

  @override
  void dispose() {
    _maennlich.dispose();
    _weiblich.dispose();
    _neutral.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final maennlich = _maennlich.text.trim();
    final weiblich = _weiblich.text.trim();
    // Der neutrale Anfang darf leer bleiben und folgt dann dem weiblichen:
    // „Sehr geehrte Damen und Herren" ist dieselbe Form wie „Sehr geehrte
    // Frau", und ein Pflichtfeld dafür wäre eine Frage ohne Erkenntnis.
    final neutral = _neutral.text.trim().isEmpty
        ? weiblich
        : _neutral.text.trim();
    if (maennlich.isEmpty || weiblich.isEmpty) return;

    setState(() => _speichert = true);
    final geglueckt = await widget.onSpeichern(
      widget.baustein.copyWith(
        maennlich: maennlich,
        weiblich: weiblich,
        neutral: neutral,
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
        widget.baustein.istGespeichert ? 'Anrede ändern' : 'Neue Anrede',
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              'Nur der Anfang. „Herr"/„Frau" und den Nachnamen setzt der '
              'Versand dazu, das Komma die Vorlage.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextField(
              controller: _maennlich,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Männlich *',
                hintText: 'Sehr geehrter',
                helperText: 'ergibt „Sehr geehrter Herr Müller"',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _weiblich,
              decoration: const InputDecoration(
                labelText: 'Weiblich *',
                hintText: 'Sehr geehrte',
                helperText: 'ergibt „Sehr geehrte Frau Schmitt"',
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              controller: _neutral,
              onSubmitted: (_) => _speichern(),
              decoration: const InputDecoration(
                labelText: 'Neutral',
                hintText: 'Sehr geehrte',
                helperText:
                    'ergibt „Sehr geehrte Damen und Herren" — leer '
                    'übernimmt die weibliche Form',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
