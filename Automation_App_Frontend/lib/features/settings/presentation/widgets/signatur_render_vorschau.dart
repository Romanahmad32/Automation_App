import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/signatur_ansicht.dart';
import 'package:flutter/material.dart';

/// Zeigt in den Einstellungen, wie die Signatur unter der Mail steht (§4.7):
/// der Text aus dem Feld darüber und darunter die Bilder der übernommenen
/// Fassung.
///
/// Vorher war an dieser Stelle nur ein Textfeld und eine Liste von Dateinamen
/// mit Größenangabe. Beides zusammen sagt nicht, wie die Signatur **aussieht** —
/// und ob das Logo überhaupt das richtige ist, sieht man an „image001.png"
/// nicht. Wer seine Signatur einmal übernimmt und dann jahrelang darauf
/// vertraut, sollte sie dabei einmal gesehen haben.
///
/// Schrift und Farben der HTML-Fassung zeigt sie bewusst nicht: Die gehören
/// Outlook, und ein ungefähres Nachbilden wäre eine Vorschau, die etwas anderes
/// behauptet als die Mail. Der Hinweis darunter sagt das.
class SignaturRenderVorschau extends StatelessWidget {
  /// Der Signaturtext, wie er gerade im Feld steht — nicht der gespeicherte:
  /// Wer tippt, soll mitlesen können.
  final String text;

  /// Die übernommene formatierte Fassung; leer bei Nur-Text. Sie wird
  /// gerendert — genau sie kommt beim Empfänger an.
  final String html;

  /// Die Bilder der übernommenen formatierten Fassung; leer bei Nur-Text.
  final List<SignaturBild> bilder;

  /// Name der aus Outlook gelesenen, noch nicht gespeicherten Signatur; sonst
  /// leer. Ohne ihn zeigte die Vorschau die Bilder der **bisherigen** Signatur,
  /// weil sie unter denselben Namen in der Ablage liegen (§4.7).
  final String ausOutlook;

  const SignaturRenderVorschau({
    super.key,
    required this.text,
    this.html = '',
    this.bilder = const [],
    this.ausOutlook = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inhalt = text.trim();
    if (inhalt.isEmpty && bilder.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                'So steht sie unter der Mail',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SignaturAnsicht(
            text: inhalt,
            html: html,
            bilder: bilder,
            ausOutlook: ausOutlook,
          ),
          if (bilder.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Outlook zeichnet Mails mit dem Word-Modul; diese Ansicht kommt '
              'nah heran, ist aber nicht pixelgleich.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
