import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:flutter/material.dart';

/// Hinweis, dass Felder aus dem gewählten Vorgang vorbelegt wurden (sichtbar
/// und änderbar — keine stille Befüllung). Zum Leeren/Wechseln dient die
/// Vorgangsauswahl oben. Stammen Werte aus einem früheren Schreiben zum selben
/// Vorgang ([anzahlGespeichert] > 0), wird die Quelle mitgenannt.
class VorgangsdatenHinweis extends StatelessWidget {
  final int anzahlFelder;

  /// Wie viele der vorbelegten Felder aus den beim letzten Schreiben
  /// bestätigten Werten stammen (0 = alle aus Mandant/Antwort/Vorgang).
  final int anzahlGespeichert;

  const VorgangsdatenHinweis({
    super.key,
    required this.anzahlFelder,
    this.anzahlGespeichert = 0,
  });

  String get _text {
    final basis = anzahlFelder == 1
        ? '1 Feld wurde aus dem Vorgang vorbelegt.'
        : '$anzahlFelder Felder wurden aus dem Vorgang vorbelegt.';
    if (anzahlGespeichert <= 0) return basis;
    final quelle = anzahlGespeichert == anzahlFelder
        ? (anzahlGespeichert == 1
              ? 'Der Wert stammt aus dem letzten Schreiben zu diesem Vorgang.'
              : 'Die Werte stammen aus dem letzten Schreiben zu diesem Vorgang.')
        : 'Davon $anzahlGespeichert aus dem letzten Schreiben zu diesem '
              'Vorgang.';
    return '$basis $quelle';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Dezenter, getoenter Hinweis statt der im Light-Mode fast schwarzen
    // secondaryContainer-Farbe.
    final tone = SoftTone.fromAccent(colorScheme.primary, colorScheme);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: tone.background,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.mark_email_read, color: tone.foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_text, style: TextStyle(color: tone.foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
