import 'package:automation_app/core/general_widgets/form/auswahl_kandidat.dart';
import 'package:flutter/material.dart';

/// Wählt einen von mehreren bekannten Werten — oder trägt einen eigenen ein.
///
/// Die freie Eingabe unter der Liste ist nicht Beiwerk, sondern die Bedingung
/// dafür, dass dieser Dialog überhaupt zumutbar ist: Er öffnet sich über ein
/// Feld, das man auch einfach tippen könnte, und darf deshalb nie eine
/// Sackgasse sein. Wer ein viertes Fahrzeug abrechnet, das im Register noch
/// nicht steht, kommt hier genauso heraus wie über die Kandidatenliste — und
/// sein Wert läuft durch dieselbe Normalisierung.
///
/// Gibt den gewählten Wert zurück; `null` bei Abbruch (auch beim Wegtippen
/// neben den Dialog) — dann bleibt das Feld unverändert.
class AuswahlDialog extends StatefulWidget {
  final String titel;
  final List<AuswahlKandidat> kandidaten;

  /// Wird auf die **freie** Eingabe angewandt, bevor sie zurückgegeben wird
  /// (z. B. ein Kennzeichen in die Konvention `HG-E 1427`). Ohne Angabe kommt
  /// der getippte Text unverändert heraus. Die Kandidaten laufen nicht
  /// hierdurch: Sie stehen sichtbar in der Liste und müssen genau so
  /// herauskommen, wie sie dort stehen.
  final String Function(String)? normalisiere;

  const AuswahlDialog({
    super.key,
    required this.titel,
    required this.kandidaten,
    this.normalisiere,
  });

  /// Öffnet den Dialog und liefert den gewählten Wert (oder `null`).
  static Future<String?> zeige(
    BuildContext context, {
    required String titel,
    required List<AuswahlKandidat> kandidaten,
    String Function(String)? normalisiere,
  }) => showDialog<String>(
    context: context,
    builder: (_) => AuswahlDialog(
      titel: titel,
      kandidaten: kandidaten,
      normalisiere: normalisiere,
    ),
  );

  @override
  State<AuswahlDialog> createState() => _AuswahlDialogState();
}

class _AuswahlDialogState extends State<AuswahlDialog> {
  final _freieEingabe = TextEditingController();

  @override
  void dispose() {
    _freieEingabe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titel),
      content: SizedBox(
        // Feste Breite, damit die Untertitelzeile („aus dem Mandantenregister")
        // nicht bei jedem Kandidaten eine andere Dialogbreite ergibt.
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final kandidat in widget.kandidaten)
                ListTile(
                  title: Text(kandidat.wert),
                  subtitle: Text(kandidat.herkunft),
                  onTap: () => Navigator.of(context).pop(kandidat.wert),
                ),
              if (widget.kandidaten.isNotEmpty) const Divider(),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _freieEingabe,
                      decoration: const InputDecoration(
                        labelText: 'Anderer Wert',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _uebernehmen(),
                    ),
                  ),
                  TextButton(
                    onPressed: _uebernehmen,
                    child: const Text('Übernehmen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }

  /// Übernimmt die freie Eingabe. Ein leeres Feld ist kein Wert — es schliesst
  /// den Dialog nicht, sonst wäre „Übernehmen" ein zweites „Abbrechen".
  void _uebernehmen() {
    final eingabe = _freieEingabe.text.trim();
    if (eingabe.isEmpty) return;
    Navigator.of(context).pop(widget.normalisiere?.call(eingabe) ?? eingabe);
  }
}
