import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_zusammenfassung_zeile.dart';
import 'package:flutter/material.dart';

/// Letzte Rückfrage vor dem Senden (§4.7). Senden ist der einzige
/// unumkehrbare Schritt des ganzen Ablaufs — anders als eine Ablage, die man
/// überschreibt, oder ein Dokument, das man neu erzeugt, holt niemand eine
/// verschickte Mail zurück. Deshalb wird hier noch einmal aufgezählt, wer sie
/// bekommt und was daran hängt.
class EmailSendenBestaetigung extends StatelessWidget {
  final EmailEntwurf entwurf;
  final String absender;

  const EmailSendenBestaetigung({
    super.key,
    required this.entwurf,
    required this.absender,
  });

  static Future<bool> zeigen(
    BuildContext context, {
    required EmailEntwurf entwurf,
    required String absender,
  }) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (_) =>
          EmailSendenBestaetigung(entwurf: entwurf, absender: absender),
    );
    return bestaetigt ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('E-Mail jetzt senden?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmailZusammenfassungZeile(beschriftung: 'Von', werte: [absender]),
            EmailZusammenfassungZeile(beschriftung: 'An', werte: entwurf.an),
            if (entwurf.kopie.isNotEmpty)
              EmailZusammenfassungZeile(
                beschriftung: 'Kopie',
                werte: entwurf.kopie,
              ),
            EmailZusammenfassungZeile(
              beschriftung: 'Betreff',
              werte: [entwurf.betreff],
            ),
            EmailZusammenfassungZeile(
              beschriftung: 'Anhänge',
              werte: entwurf.anhangPfade.isEmpty
                  ? const ['— keine —']
                  : entwurf.anhangPfade.map(AnhangDarstellung.name).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Eine gesendete E-Mail lässt sich nicht zurückholen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Zurück'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.send),
          label: const Text('Senden'),
        ),
      ],
    );
  }
}
