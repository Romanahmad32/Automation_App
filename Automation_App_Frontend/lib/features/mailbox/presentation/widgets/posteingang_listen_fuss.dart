import 'package:flutter/material.dart';

/// Die Fußzeile der Posteingangsliste: „Ältere laden (50 von n)", solange es
/// mehr gibt; ist alles geladen, ein Text — beim Deckel (500 Zeilen,
/// Entscheidung 8.2) der Hinweis, ältere Nachrichten im Mailprogramm
/// anzusehen, statt „Alle n geladen" zu behaupten.
class PosteingangListenFuss extends StatelessWidget {
  const PosteingangListenFuss({
    super.key,
    required this.geladen,
    required this.gesamt,
    required this.alleGeladen,
    required this.laedt,
    required this.onMehr,
  });

  final int geladen;
  final int gesamt;
  final bool alleGeladen;
  final bool laedt;
  final VoidCallback onMehr;

  static const int seitengroesse = 50;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Center(child: _inhalt(context)),
    );
  }

  Widget _inhalt(BuildContext context) {
    final theme = Theme.of(context);
    if (!alleGeladen) {
      return TextButton(
        onPressed: laedt ? null : onMehr,
        child: laedt
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('Ältere laden ($seitengroesse von ${_tausender(gesamt)})'),
      );
    }
    if (geladen >= gesamt) {
      return Text(
        'Alle ${_tausender(gesamt)} Nachrichten geladen',
        style: theme.textTheme.bodySmall,
      );
    }
    return Text(
      'Weitere Nachrichten liegen im Postfach — bitte im Mailprogramm ansehen.',
      style: theme.textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }

  static String _tausender(int wert) {
    final text = wert.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}
