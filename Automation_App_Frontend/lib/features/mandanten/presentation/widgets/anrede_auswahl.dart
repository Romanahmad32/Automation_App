import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:flutter/material.dart';

/// Auswahl der Anrede/des Geschlechts eines Mandanten (Herr / Frau / keine
/// Angabe). Bestimmt die spätere Ansprache in Vorlagen und E-Mails. Liefert die
/// Auswahl über [onChanged] zurück; der Aufrufer hält den Wert (analog zum
/// KennzeichenEditor).
class AnredeAuswahl extends StatefulWidget {
  final Anrede initialAnrede;
  final ValueChanged<Anrede> onChanged;

  const AnredeAuswahl({
    super.key,
    required this.initialAnrede,
    required this.onChanged,
  });

  @override
  State<AnredeAuswahl> createState() => _AnredeAuswahlState();
}

class _AnredeAuswahlState extends State<AnredeAuswahl> {
  late Anrede _anrede = widget.initialAnrede;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<Anrede>(
        segments: const [
          ButtonSegment(value: Anrede.herr, label: Text('Herr')),
          ButtonSegment(value: Anrede.frau, label: Text('Frau')),
          ButtonSegment(value: Anrede.keine, label: Text('Keine Angabe')),
        ],
        selected: {_anrede},
        onSelectionChanged: (selection) {
          setState(() => _anrede = selection.first);
          widget.onChanged(_anrede);
        },
      ),
    );
  }
}
