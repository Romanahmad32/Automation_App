import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';

/// Rückfrage vor dem Löschen eines Vorgangs (§6.3): Ob die gespiegelte
/// Registerzeile (§6.2) dabei bleibt oder mitgeht.
///
/// Eigener Dialog statt einer Erweiterung von `bestaetigen()`
/// (`bestaetigungs_dialog.dart`): Der ist auf reine Ja/Nein-Rückfragen
/// zugeschnitten und wird an vielen Stellen der App verwendet — eine dritte
/// Auswahl hier hinzuzufügen, hätte jeden dieser Aufrufe mitgeändert. Die
/// Vorlage ist stattdessen `VorgangAbschliessenDialog`
/// (`word_automation/presentation/widgets/vorgang_abschliessen_dialog.dart`):
/// derselbe Aufbau aus `AlertDialog` + `CheckboxListTile` für eine Rückfrage
/// mit genau einer zusätzlichen Entscheidung.
///
/// Vorbelegt ist „behalten" — die Antwort, die nichts zusätzlich löscht
/// (§6.3 „Beide Fragen sind Haltepunkte, nicht Vorbelegungen"). Bleibt sie,
/// wird aus der gespiegelten Zeile eine eigenständige Zeile der übernommenen
/// Historie (§6.2 „Eigenständig") — durchsuchbar und filterbar, aber ohne
/// Vorgang dahinter.
///
/// Liefert per `Navigator.pop`, ob die Registerzeile behalten werden soll;
/// `null`, wenn abgebrochen wurde.
class VorgangLoeschenDialog extends StatefulWidget {
  final Vorgang vorgang;

  const VorgangLoeschenDialog({super.key, required this.vorgang});

  @override
  State<VorgangLoeschenDialog> createState() => VorgangLoeschenDialogState();
}

class VorgangLoeschenDialogState extends State<VorgangLoeschenDialog> {
  bool _registerzeileBehalten = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Vorgang „${widget.vorgang.zeichen}" löschen?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Der Vorgang wird endgültig gelöscht. Dies kann nicht '
              'rückgängig gemacht werden.',
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _registerzeileBehalten,
              onChanged: (wert) =>
                  setState(() => _registerzeileBehalten = wert ?? true),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Registerzeile behalten'),
              subtitle: Text(
                'Die Zeile bleibt als übernommene Registerzeile im '
                'Sachgebiete-Register stehen, ohne Vorgang dahinter.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(_registerzeileBehalten),
          child: const Text('Löschen'),
        ),
      ],
    );
  }
}
