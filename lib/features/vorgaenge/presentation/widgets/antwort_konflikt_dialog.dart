import 'package:automation_app/features/vorgaenge/domain/services/antwort_konflikte.dart';
import 'package:flutter/material.dart';

/// Dialog vor der Übernahme einer Zentralruf-Antwort, wenn sie bereits
/// erfassten Vorgangsdaten widerspricht: zeigt je Abweichung beide Werte und
/// lässt den Anwalt pro Feld wählen, ob der erfasste Wert stehen bleibt
/// (Standard, bisheriges Verhalten) oder der Antwortwert übernommen wird.
/// „Abbrechen" bricht die gesamte Übernahme ab.
class AntwortKonfliktDialog extends StatefulWidget {
  final List<AntwortKonflikt> konflikte;

  const AntwortKonfliktDialog({super.key, required this.konflikte});

  /// Zeigt den Dialog und liefert die Felder, bei denen der Antwortwert
  /// gewinnen soll — oder null, wenn der Anwalt die Übernahme abbricht.
  static Future<Set<AntwortKonfliktFeld>?> zeige(
    BuildContext context,
    List<AntwortKonflikt> konflikte,
  ) {
    return showDialog<Set<AntwortKonfliktFeld>>(
      context: context,
      builder: (context) => AntwortKonfliktDialog(konflikte: konflikte),
    );
  }

  @override
  State<AntwortKonfliktDialog> createState() => _AntwortKonfliktDialogState();
}

class _AntwortKonfliktDialogState extends State<AntwortKonfliktDialog> {
  final Set<AntwortKonfliktFeld> _antwortGewinnt = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(Icons.difference_outlined),
      title: const Text('Antwort weicht von erfassten Daten ab'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Die Zentralruf-Antwort enthält Werte, die von den bereits am '
                'Vorgang erfassten Daten abweichen. Bitte je Feld entscheiden, '
                'welcher Wert gelten soll.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final konflikt in widget.konflikte)
                AntwortKonfliktAuswahl(
                  konflikt: konflikt,
                  antwortGewaehlt: _antwortGewinnt.contains(konflikt.feld),
                  onChanged: (nimmAntwort) => setState(() {
                    nimmAntwort
                        ? _antwortGewinnt.add(konflikt.feld)
                        : _antwortGewinnt.remove(konflikt.feld);
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(Set.of(_antwortGewinnt)),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

/// Auswahlkarte für eine einzelne Abweichung: erfasster Wert gegen Antwortwert
/// als exklusive Zwei-Fach-Auswahl.
class AntwortKonfliktAuswahl extends StatelessWidget {
  final AntwortKonflikt konflikt;
  final bool antwortGewaehlt;
  final ValueChanged<bool> onChanged;

  const AntwortKonfliktAuswahl({
    super.key,
    required this.konflikt,
    required this.antwortGewaehlt,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              konflikt.feld.displayName,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.edit_note),
                  label: Text('Erfasst: ${konflikt.erfassterWert}'),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.mark_email_read_outlined),
                  label: Text('Antwort: ${konflikt.antwortWert}'),
                ),
              ],
              selected: {antwortGewaehlt},
              onSelectionChanged: (auswahl) => onChanged(auswahl.first),
            ),
          ],
        ),
      ),
    );
  }
}
