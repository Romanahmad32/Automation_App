import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Warnt am Feld, wenn die eingegebene Auftragsnummer im Jahrgang schon
/// vergeben ist (§6.3) — sagt es „deutlich", **ohne** das Speichern zu
/// sperren: Das gewachsene Register der Kanzlei enthält echte Doubletten,
/// und was im Bestand steht, muss eintragbar bleiben.
///
/// Deshalb bewusst **kein** `FormControl`-Validator an `auftragsnummer` (das
/// würde `formGroup.valid` und damit den Speichern-Knopf sperren — der Weg,
/// mit dem `word_automation` unlesbare RVG-Werte anhält). Stattdessen nur ein
/// Hinweistext, der live auf den Feldwert hört, nach demselben Muster wie
/// `FeldNameHinweis` in `form_template_setup`.
class AuftragsnummerBelegtHinweis extends StatelessWidget {
  /// Die im geladenen Jahrgang schon vergebenen Nummern — leer, solange der
  /// Nummernstand nicht geladen ist oder der Abruf scheiterte (dann bleibt
  /// dieser Hinweis stumm).
  final List<int> belegteNummern;

  /// Der Jahrgang, zu dem [belegteNummern] gehört — für den Wortlaut der
  /// Meldung.
  final String? jahr;

  const AuftragsnummerBelegtHinweis({
    super.key,
    required this.belegteNummern,
    required this.jahr,
  });

  @override
  Widget build(BuildContext context) {
    if (belegteNummern.isEmpty || jahr == null) return const SizedBox.shrink();

    return ReactiveValueListenableBuilder<String>(
      formControlName: 'auftragsnummer',
      builder: (context, control, _) {
        final nummer = int.tryParse((control.value ?? '').trim());
        if (nummer == null || !belegteNummern.contains(nummer)) {
          return const SizedBox.shrink();
        }
        return FehlerHinweis(
          nachricht: 'Nummer $nummer ist im Jahrgang $jahr schon vergeben.',
        );
      },
    );
  }
}
