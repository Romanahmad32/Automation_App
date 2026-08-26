import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
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

  /// Der Signaturblock, den der Versand anfügt. Er steht mit im Text, damit
  /// hier wirklich die Mail steht, die hinausgeht — und nicht fast.
  final String signatur;

  const EmailSendenBestaetigung({
    super.key,
    required this.entwurf,
    required this.absender,
    this.signatur = '',
  });

  static Future<bool> zeigen(
    BuildContext context, {
    required EmailEntwurf entwurf,
    required String absender,
    String signatur = '',
  }) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (_) => EmailSendenBestaetigung(
        entwurf: entwurf,
        absender: absender,
        signatur: signatur,
      ),
    );
    return bestaetigt ?? false;
  }

  /// Der vollständige Text, wie ihn der Empfänger sieht.
  String get _volltext {
    final block = signatur.trim();
    if (block.isEmpty) return entwurf.text;
    return '${entwurf.text.trimRight()}\n\n$block';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('E-Mail jetzt senden?'),
      content: SizedBox(
        width: 560,
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
                  : entwurf.anhangPfade.map(entwurf.nameVon).toList(),
            ),
            const Divider(height: 20),
            Text(
              'Nachricht',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 6),
            // Scrollbar begrenzt: Ein langes Anschreiben darf die Schaltflächen
            // nicht aus dem Fenster schieben.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: SelectableText(
                  _volltext,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
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
