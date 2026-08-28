import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/signatur_ansicht.dart';
import 'package:flutter/material.dart';

/// Zeigt unter dem Nachrichtenfeld, was der Direktversand noch anfügt (§4.7).
///
/// Die Signatur gehört den Einstellungen, nicht dem einzelnen Entwurf — sonst
/// müsste sie bei jedem Nachziehen der Anrede mitwandern. Sichtbar muss sie
/// trotzdem sein: Was unter der Mail steht, soll der Anwalt gesehen haben,
/// bevor sie hinausgeht, und nicht erst im Ordner „Gesendet".
///
/// Bewusst nicht änderbar. Wer hier tippen könnte, würde es je Mail tun, und
/// die gepflegte Fassung in den Einstellungen veraltete still.
class EmailSignaturVorschau extends StatelessWidget {
  final String signatur;

  /// Die formatierte Fassung — sie wird gerendert, weil genau sie beim
  /// Empfänger ankommt. Der Text daneben ist nur Outlooks Übersetzung für
  /// Programme, die kein HTML anzeigen.
  final String html;

  /// Die Bilder der formatierten Signatur.
  final List<SignaturBild> bilder;

  /// Dateinamen, die für diese Mail weggelassen wurden.
  final List<String> weggelassen;

  const EmailSignaturVorschau({
    super.key,
    required this.signatur,
    this.html = '',
    this.bilder = const [],
    this.weggelassen = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Gar nichts anzuzeigen war die erste Fassung — und beim Testen fiel genau
    // das auf: Ohne hinterlegte Signatur fehlte die Vorschau spurlos, und
    // nichts sagte, warum. Der Hinweis kostet eine Zeile.
    if (signatur.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 2),
        child: Row(
          children: [
            Icon(
              Icons.draw_outlined,
              size: 14,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Keine Signatur hinterlegt — in den Einstellungen aus Outlook '
                'übernehmen.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.draw_outlined,
                size: 14,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Signatur aus den Einstellungen — beim Entwurf in Outlook '
                  'setzt Outlook stattdessen seine eigene',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SignaturAnsicht(
            text: signatur,
            html: html,
            bilder: bilder,
            weggelassen: weggelassen,
          ),
        ],
      ),
    );
  }
}
