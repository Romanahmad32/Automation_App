import 'package:flutter/material.dart';

/// Umschalter „Formatiert | Text" über dem Mailtext (Issue #134) — ein
/// `SegmentedButton`, weil es zwei Ansichten **derselben** Nachricht sind,
/// kein Chip-Filter (Auswahl-Vokabular der Mailbox, siehe FALLSTRICKE.md).
///
/// Der Aufrufer zeigt dieses Widget nur, wenn `PosteingangInhalt.hatHtml`
/// zutrifft — ohne HTML-Fassung gibt es nichts umzuschalten.
class PosteingangAnsichtUmschalter extends StatelessWidget {
  const PosteingangAnsichtUmschalter({
    super.key,
    required this.formatiert,
    required this.onChanged,
  });

  /// True = Formatiert (HTML), false = Text.
  final bool formatiert;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: true, label: Text('Formatiert')),
        ButtonSegment(value: false, label: Text('Text')),
      ],
      selected: {formatiert},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
