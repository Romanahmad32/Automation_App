import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Sagt unter einem Vorlagenfeld, warum sein Name **nicht** an eine Datenquelle
/// gebunden werden konnte — heute der Fall, dass er zwei Angaben zugleich meint
/// (`{{VersicherungPlzOrt}}`, `{{MandantVornameNachname}}`).
///
/// Warum überhaupt an dieser Stelle: Solche Namen lieferten früher still nur
/// die erste der beiden Angaben. Der Fehler steckte damit in jedem erzeugten
/// Brief und fiel niemandem auf. Hier fällt er genau einmal auf — beim
/// Einrichten der Vorlage, wo er sich beheben lässt (§1.3).
///
/// Hört live auf den Feldnamen, weil der Anwalt ihn im selben Formular tippt.
/// Steht am Feld eine Datenquelle, schweigt der Hinweis: Sie gewinnt ohnehin
/// über die Erkennung, der Name ist dann für die Vorbelegung ohne Belang.
class FeldNameHinweis extends StatelessWidget {
  /// Schlüssel des reactive_forms-Controls, in dem der Feldname steht.
  final String formControlName;

  /// Ob am Feld überhaupt eine Datenquelle steht — von Hand gewählt oder beim
  /// Übernehmen des Platzhalters vorgeschlagen (`neuesFeld`). Beides zählt:
  /// Der Hinweis erklärt einen *ungebundenen* Namen, sonst nichts.
  final bool datenquelleGesetzt;

  const FeldNameHinweis({
    super.key,
    required this.formControlName,
    required this.datenquelleGesetzt,
  });

  @override
  Widget build(BuildContext context) {
    if (datenquelleGesetzt) return const SizedBox.shrink();

    return ReactiveValueListenableBuilder<String>(
      formControlName: formControlName,
      builder: (context, control, _) {
        final hinweis = FeldDatenquelleErkennung.erkenne(
          control.value ?? '',
        ).hinweis;
        if (hinweis == null) return const SizedBox.shrink();
        // Ohne eigene Einrückung: Der Hinweis steht jetzt im Aufklapper der
        // Feldzeile (`FeldAufklappInhalt`), und der rückt seinen ganzen Inhalt
        // gemeinsam unter die Bezeichnungsspalte ein. Die früheren 46 px hier
        // kämen zu dessen 48 dazu und schöben ihn aus der Spalte.
        return FehlerHinweis(nachricht: hinweis);
      },
    );
  }
}
