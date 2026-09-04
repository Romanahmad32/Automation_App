import 'package:automation_app/core/general_classes/kennzeichen_normalisierung.dart';
import 'package:automation_app/core/general_widgets/form/kennzeichen_field.dart';
import 'package:automation_app/core/general_widgets/form/texte_listen_editor.dart';
import 'package:flutter/material.dart';

/// Editor für die optionalen Kfz-Kennzeichen eines Mandanten (0..n). Die
/// Bauform — löschbare Chips über einem Eingabefeld — kommt aus
/// [TexteListenEditor]; hier steht nur, was am Kennzeichen besonders ist:
/// Großschreibung, die Konvention `HG-E 1427` und deren Prüfung beim
/// Hinzufügen.
///
/// Prüfung und Hinweistext kommen von [KennzeichenField], damit hier keine
/// zweite Auffassung davon entsteht, was ein Kennzeichen ist. Aufgenommen wird
/// der **normalisierte** Wert: So steht in der Liste die Konvention, und
/// `hge1427` fällt als Dublette zu `HG-E 1427` auf statt als zweiter Wagen.
class KennzeichenEditor extends StatelessWidget {
  /// Bereits hinterlegte Kennzeichen (Ausgangswert).
  final List<String> initialKennzeichen;

  /// Wird bei jeder Änderung mit der vollständigen, aktuellen Liste aufgerufen.
  final ValueChanged<List<String>> onChanged;

  const KennzeichenEditor({
    super.key,
    required this.initialKennzeichen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TexteListenEditor(
      initialWerte: initialKennzeichen,
      onChanged: onChanged,
      labelText: 'Kennzeichen',
      helperText: KennzeichenField.hinweis,
      chipIcon: Icons.directions_car_outlined,
      entfernenTooltip: 'Kennzeichen entfernen',
      hinzufuegenTooltip: 'Kennzeichen hinzufügen',
      textCapitalization: TextCapitalization.characters,
      dublettenHinweis: 'Dieses Kennzeichen ist bereits hinterlegt',
      normalisiere: (eingabe) => normalizeKennzeichen(eingabe) ?? eingabe,
      pruefe: (eingabe) =>
          istKennzeichen(eingabe) ? null : KennzeichenField.hinweis,
    );
  }
}
