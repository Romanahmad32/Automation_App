import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_vorschau.dart';
import 'package:flutter/material.dart';

/// Die Vorschau als ständige Seitenspalte des Versanddialogs (§4.7) — sie
/// schreibt beim Tippen mit.
///
/// Die Vorschau lag zuerst hinter einem Knopf. Wer wissen wollte, was
/// hinausgeht, musste sie also erst anfordern — und tat es deshalb meist nicht.
/// Nebenan sichtbar, ist die Frage „steht da wirklich das Richtige?"
/// beantwortet, bevor sie aufkommt.
class EmailVorschauSpalte extends StatelessWidget {
  final EmailEntwurf entwurf;
  final String absender;
  final String signatur;

  /// Die formatierte Fassung — sie wird gerendert.
  final String signaturHtml;

  /// Die Bilder der formatierten Signatur — die Vorschau zeigt sie mit.
  final List<SignaturBild> signaturBilder;

  const EmailVorschauSpalte({
    super.key,
    required this.entwurf,
    required this.absender,
    this.signatur = '',
    this.signaturHtml = '',
    this.signaturBilder = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              'Vorschau — so geht die Mail hinaus',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            // Rechts schmal: Dort läuft die Bildlaufleiste der Vorschau, und
            // sie soll am Rand der Fläche sitzen, nicht darin.
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: EmailVorschau(
              entwurf: entwurf,
              absender: absender,
              signatur: signatur,
              signaturHtml: signaturHtml,
              signaturBilder: signaturBilder,
            ),
          ),
        ),
      ],
    );
  }
}
