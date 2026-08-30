import 'package:automation_app/core/general_widgets/form/texte_listen_editor.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/vorgang_form_validators.dart';
import 'package:flutter/material.dart';

/// Editor für die optionalen Kfz-Kennzeichen eines Mandanten (0..n). Die
/// Bauform — löschbare Chips über einem Eingabefeld — kommt aus
/// [TexteListenEditor]; hier steht nur, was am Kennzeichen besonders ist:
/// Großschreibung, die Schreibweise mit Bindestrich (z. B. `HG-E 1427`) und
/// deren Prüfung beim Hinzufügen.
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
      helperText: kennzeichenHinweis,
      chipIcon: Icons.directions_car_outlined,
      entfernenTooltip: 'Kennzeichen entfernen',
      hinzufuegenTooltip: 'Kennzeichen hinzufügen',
      textCapitalization: TextCapitalization.characters,
      dublettenHinweis: 'Dieses Kennzeichen ist bereits hinterlegt',
      pruefe: (eingabe) =>
          istGueltigesKennzeichen(eingabe) ? null : kennzeichenHinweis,
    );
  }
}
