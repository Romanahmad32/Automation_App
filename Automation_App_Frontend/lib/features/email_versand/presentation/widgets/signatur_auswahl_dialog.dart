import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:flutter/material.dart';

/// Lässt wählen, welche der in Outlook eingerichteten Signaturen übernommen
/// wird (§4.7). Eine Kanzlei hat oft mehrere — „Kurz" für den Alltag,
/// „Vollständig" mit allen Pflichtangaben —, und welche unter das
/// Anspruchsschreiben gehört, weiß nur der Anwalt.
///
/// Bei genau einer Signatur wird nicht gefragt; siehe [zeigen].
class SignaturAuswahlDialog extends StatelessWidget {
  final List<OutlookSignatur> signaturen;

  const SignaturAuswahlDialog({super.key, required this.signaturen});

  /// Liefert die gewählte Signatur, oder null bei Abbruch. Ist nur eine
  /// vorhanden, wird sie ohne Rückfrage genommen — eine Auswahl aus einem
  /// einzigen Eintrag ist keine Frage, sondern ein zusätzlicher Klick.
  static Future<OutlookSignatur?> zeigen(
    BuildContext context,
    List<OutlookSignatur> signaturen,
  ) async {
    if (signaturen.isEmpty) return null;
    if (signaturen.length == 1) return signaturen.first;

    return showDialog<OutlookSignatur>(
      context: context,
      builder: (_) => SignaturAuswahlDialog(signaturen: signaturen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Welche Signatur übernehmen?'),
      content: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final signatur in signaturen)
              ListTile(
                leading: const Icon(Icons.draw_outlined),
                title: Text(signatur.name),
                subtitle: Text(
                  signatur.vorschau,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                onTap: () => Navigator.pop(context, signatur),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}
