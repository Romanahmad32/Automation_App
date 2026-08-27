import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:flutter/material.dart';

/// Sagt, ob unter der Mail die formatierte Signatur steht oder nur der Text —
/// und was ihre Bilder wiegen (§4.7).
///
/// Ohne diese Zeile wäre die Übernahme eine Blackbox: Das Textfeld darunter
/// zeigt die Nur-Text-Fassung, hinausgehen würde aber die formatierte. Wer
/// nicht weiß, dass es sie gibt, wundert sich über Logo und Schrift beim
/// Empfänger — oder darüber, dass die Mail plötzlich Megabyte wiegt.
class SignaturFormatZeile extends StatelessWidget {
  final SignaturStand stand;

  /// Wirft die formatierte Fassung weg; der Text bleibt.
  final VoidCallback onVerwerfen;

  final bool aktiv;

  const SignaturFormatZeile({
    super.key,
    required this.stand,
    required this.onVerwerfen,
    this.aktiv = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!stand.hatFormat) {
      return _hinweis(
        theme,
        Icons.text_fields,
        'Nur-Text-Signatur — sie geht so hinaus, wie sie unten steht.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hinweis(
          theme,
          Icons.format_paint_outlined,
          'Formatierte Fassung übernommen: Schrift, Farben und Bilder gehen '
          'mit. Der Text unten ist die Fassung für Empfänger, die kein HTML '
          'anzeigen.',
        ),
        if (stand.bilder.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final bild in stand.bilder)
                Chip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: Text(
                    '${bild.dateiname} · '
                    '${AnhangDarstellung.alsGroesse(bild.bytes)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Zusammen ${AnhangDarstellung.alsGroesse(stand.bilderBytes)}. Beim '
            'Verfassen lässt sich je Mail entscheiden, welche davon mitgehen.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: aktiv ? onVerwerfen : null,
            icon: const Icon(Icons.format_clear, size: 18),
            label: const Text('Formatierung verwerfen'),
          ),
        ),
      ],
    );
  }

  Widget _hinweis(ThemeData theme, IconData symbol, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(symbol, size: 16, color: theme.colorScheme.outline),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    ],
  );
}
