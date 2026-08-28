import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_hinweis_kasten.dart';
import 'package:flutter/material.dart';

/// Sagt oben im Dialog, warum **nicht** gesendet werden kann (§4.7). Steht
/// bewusst über dem Formular: Wer erst nach dem Tippen erfährt, dass die
/// Anmeldung abgelaufen ist, hat umsonst getippt.
///
/// Im Regelfall ist hier nichts — und das ist der Punkt. „Wird gesendet von
/// kanzlei@…" stand hier früher als eigener Kasten und nahm dauerhaft Platz
/// für eine Zeile weg, die sich nie ändert. Die Absenderadresse steht jetzt in
/// der Titelzeile des Dialogs und in der Vorschau unter „Von".
class EmailBereitschaftHinweis extends StatelessWidget {
  final EmailVersandBereitschaft? bereitschaft;

  /// Meldung des letzten fehlgeschlagenen Versuchs; sonst null.
  final String? fehler;

  const EmailBereitschaftHinweis({
    super.key,
    required this.bereitschaft,
    this.fehler,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (fehler != null) {
      return EmailHinweisKasten(
        farbe: theme.colorScheme.errorContainer,
        vordergrund: theme.colorScheme.onErrorContainer,
        symbol: Icons.error_outline,
        text: fehler!,
      );
    }

    final stand = bereitschaft;
    if (stand == null) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (!stand.bereit) {
      return EmailHinweisKasten(
        farbe: theme.colorScheme.errorContainer,
        vordergrund: theme.colorScheme.onErrorContainer,
        symbol: Icons.warning_amber_outlined,
        text:
            stand.hinweis ??
            'Es kann derzeit nicht gesendet werden. Bitte den Postfach-Zugang '
                'in den Einstellungen prüfen.',
      );
    }

    return const SizedBox.shrink();
  }
}
