import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_vorschau.dart';
import 'package:flutter/material.dart';

/// Letzte Rückfrage vor dem Senden (§4.7). Senden ist der einzige
/// unumkehrbare Schritt des ganzen Ablaufs — anders als eine Ablage, die man
/// überschreibt, oder ein Dokument, das man neu erzeugt, holt niemand eine
/// verschickte Mail zurück. Deshalb steht hier noch einmal die vollständige
/// Mail: wer sie bekommt, was daran hängt und was drinsteht.
class EmailSendenBestaetigung extends StatelessWidget {
  final EmailEntwurf entwurf;
  final String absender;

  /// Der Signaturblock, den der Versand anfügt. Er steht mit im Text, damit
  /// hier wirklich die Mail steht, die hinausgeht — und nicht fast.
  final String signatur;

  /// Die formatierte Fassung — sie wird gerendert.
  final String signaturHtml;

  /// Die Bilder der Signatur, so wie sie mit dieser Mail hinausgehen.
  final List<SignaturBild> signaturBilder;

  const EmailSendenBestaetigung({
    super.key,
    required this.entwurf,
    required this.absender,
    this.signatur = '',
    this.signaturHtml = '',
    this.signaturBilder = const [],
  });

  static Future<bool> zeigen(
    BuildContext context, {
    required EmailEntwurf entwurf,
    required String absender,
    String signatur = '',
    String signaturHtml = '',
    List<SignaturBild> signaturBilder = const [],
  }) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (_) => EmailSendenBestaetigung(
        entwurf: entwurf,
        absender: absender,
        signatur: signatur,
        signaturHtml: signaturHtml,
        signaturBilder: signaturBilder,
      ),
    );
    return bestaetigt ?? false;
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
            SizedBox(
              height: 380,
              child: EmailVorschau(
                entwurf: entwurf,
                absender: absender,
                signatur: signatur,
                signaturHtml: signaturHtml,
                signaturBilder: signaturBilder,
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
