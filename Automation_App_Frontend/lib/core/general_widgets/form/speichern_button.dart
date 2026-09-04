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

  /// Für die Kopfzeile eines Einstellungs-Reiters
  /// (`EinstellungenAktionszeile`): flacher und ohne das rechtsbündige
  /// [Align]. Der Knopf des Themes ist 56 px hoch — in einer Zeile, die selbst
  /// nur 60 px hoch sein soll, ist er das ganze Band; und ausrichten tut ihn
  /// dort die Zeile.
  final bool kompakt;

  const SpeichernButton({
    super.key,
    required this.onSpeichern,
    this.speichert = false,
    this.beschriftung = 'Speichern',
    this.kompakt = false,
  });

  @override
  Widget build(BuildContext context) {
    final knopf = FilledButton.icon(
      onPressed: speichert ? null : onSpeichern,
      // Nur die Polsterung überschreiben; Form, Schrift und Farben kommen
      // weiter aus dem `filledButtonTheme`.
      style: kompakt
          ? FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            )
          : null,
      icon: speichert
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(beschriftung),
    );

    return kompakt
        ? knopf
        : Align(alignment: Alignment.centerRight, child: knopf);
  }
}
