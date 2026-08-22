import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:flutter/material.dart';

/// Zeigt vor dem Speichern eine kurze Übersicht, was am Mandanten angelegt
/// ([istNeu] = true) oder geändert würde, und lässt den Nutzer bestätigen oder
/// abbrechen (Req. 3). Liefert `true` (bestätigt) oder `null`/`false`
/// (abgebrochen → nichts speichern).
class MandantUebersichtDialog extends StatelessWidget {
  final bool istNeu;
  final List<MandantFeldDiff> zeilen;

  const MandantUebersichtDialog({
    super.key,
    required this.istNeu,
    required this.zeilen,
  });

  static Future<bool?> zeige(
    BuildContext context, {
    required bool istNeu,
    required List<MandantFeldDiff> zeilen,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => MandantUebersichtDialog(istNeu: istNeu, zeilen: zeilen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        istNeu ? Icons.person_add_alt_1_outlined : Icons.edit_note_outlined,
      ),
      title: Text(
        istNeu ? 'Neuen Mandanten anlegen' : 'Mandantendaten aktualisieren',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            istNeu
                ? 'Mit diesen Daten wird ein neuer Mandant im Register angelegt:'
                : 'Folgende Daten werden beim Mandanten geändert:',
          ),
          const SizedBox(height: 12),
          for (final zeile in zeilen)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MandantUebersichtZeile(zeile: zeile, istNeu: istNeu),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(istNeu ? 'Anlegen' : 'Aktualisieren'),
        ),
      ],
    );
  }
}

/// Eine Zeile der Mandanten-Übersicht: „Label: Wert" bei Anlage,
/// „Label: alt → neu" bei Aktualisierung (leerer Altwert als „(leer)").
class MandantUebersichtZeile extends StatelessWidget {
  final MandantFeldDiff zeile;
  final bool istNeu;

  const MandantUebersichtZeile({
    super.key,
    required this.zeile,
    required this.istNeu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fett = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: [
          TextSpan(text: '${zeile.label}: ', style: fett),
          if (istNeu)
            TextSpan(text: zeile.neu)
          else ...[
            TextSpan(
              text: zeile.alt.isEmpty ? '(leer)' : zeile.alt,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
                decorationColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const TextSpan(text: '  →  '),
            TextSpan(
              text: zeile.neu.isEmpty ? '(leer)' : zeile.neu,
              style: fett,
            ),
          ],
        ],
      ),
    );
  }
}
