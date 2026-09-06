import 'package:flutter/material.dart';

/// Die zwei Ansichten, zwischen denen der Versanddialog und der
/// Vorlageneditor umschalten: **schreiben** oder **prüfen** (§4.7).
enum VersandAnsicht {
  bearbeiten('Bearbeiten', Icons.edit_outlined),
  vorschau('Vorschau', Icons.visibility_outlined);

  final String bezeichnung;
  final IconData symbol;

  const VersandAnsicht(this.bezeichnung, this.symbol);
}

/// Der Umschalter Bearbeiten ↔ Vorschau — auf **jeder** Fensterbreite.
///
/// **Der Mangel, den das behebt:** Die Vorschau lag unter 1180 px hinter einem
/// Knopf, der ein zweites Fenster öffnete. Wer prüfen wollte, verliess damit
/// das Formular; §4.7 verlangt die Sichtprüfung aber, *während* geschrieben
/// wird. Jetzt bleibt sie im selben Dialog, einen Segmentklick entfernt — und
/// wo Platz für zwei Spalten ist, steht sie ohnehin schon daneben. Dort
/// schaltet dieser Umschalter die Vorschau auf die **ganze** Breite: der Blick
/// zum Schluss, bevor gesendet wird.
///
/// [SegmentedButton] und nicht zwei Knöpfe: Es ist eine Wahl zwischen zwei
/// Zuständen, keine Handlung. Das Vokabular dazu steht in `AuswahlThemes`.
class AnsichtUmschalter extends StatelessWidget {
  final VersandAnsicht gewaehlt;
  final ValueChanged<VersandAnsicht> onWechsel;

  /// Sagt, was die Vorschau in dieser Lage **zusätzlich** bringt; null lässt
  /// die Zeile weg. Neben einer schon sichtbaren Vorschau ist das nicht „auch
  /// noch mal ansehen", sondern „ganz gross ansehen".
  final String? hinweis;

  const AnsichtUmschalter({
    super.key,
    required this.gewaehlt,
    required this.onWechsel,
    this.hinweis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SegmentedButton<VersandAnsicht>(
          segments: [
            for (final ansicht in VersandAnsicht.values)
              ButtonSegment<VersandAnsicht>(
                value: ansicht,
                label: Text(ansicht.bezeichnung),
                icon: Icon(ansicht.symbol, size: 18),
              ),
          ],
          selected: {gewaehlt},
          onSelectionChanged: (wahl) => onWechsel(wahl.first),
        ),
        if (hinweis != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hinweis!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
