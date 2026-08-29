import 'package:flutter/material.dart';

/// Der Speichern-Knopf einer Einstellungsseite: rechtsbündig, mit Ring
/// während des Schreibens.
///
/// Eigener Baustein, weil dieselben zwanzig Zeilen in jeder Einstellungsmaske
/// standen — und weil beim Nachbauen jedes Mal etwas anders aussah. Er ist
/// bewusst der **eine** Knopf seiner Seite: Zwei davon untereinander sehen aus
/// wie zwei Formulare, und niemand kann raten, wo die Grenze zwischen ihnen
/// verläuft.
class SpeichernButton extends StatelessWidget {
  final VoidCallback? onSpeichern;

  /// Zeigt den Ring statt des Symbols und sperrt den Knopf.
  final bool speichert;

  final String beschriftung;

  const SpeichernButton({
    super.key,
    required this.onSpeichern,
    this.speichert = false,
    this.beschriftung = 'Speichern',
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: speichert ? null : onSpeichern,
        icon: speichert
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(beschriftung),
      ),
    );
  }
}
