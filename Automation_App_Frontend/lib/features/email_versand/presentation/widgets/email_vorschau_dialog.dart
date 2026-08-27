import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_vorschau.dart';
import 'package:flutter/material.dart';

/// Zeigt die Mail, wie sie hinausgeht — jederzeit, nicht erst beim Absenden
/// (§4.7).
///
/// Die Vorschau steckte anfangs nur in der Rückfrage vor dem Senden. Wer sich
/// vergewissern wollte, musste also erst auf „Senden" drücken; bei dem einen
/// unumkehrbaren Schritt des Ablaufs ist das die falsche Reihenfolge.
class EmailVorschauDialog extends StatelessWidget {
  final EmailEntwurf entwurf;
  final String absender;
  final String signatur;

  const EmailVorschauDialog({
    super.key,
    required this.entwurf,
    required this.absender,
    this.signatur = '',
  });

  static Future<void> zeigen(
    BuildContext context, {
    required EmailEntwurf entwurf,
    required String absender,
    String signatur = '',
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => EmailVorschauDialog(
        entwurf: entwurf,
        absender: absender,
        signatur: signatur,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vorschau'),
      content: SizedBox(
        width: 560,
        child: EmailVorschau(
          entwurf: entwurf,
          absender: absender,
          signatur: signatur,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Weiter bearbeiten'),
        ),
      ],
    );
  }
}
