import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:flutter/material.dart';

/// Die Bilder, die in der formatierten Signatur stecken — je Mail an- oder
/// abwählbar (§4.7).
///
/// Der Anlass steht im Alltag der Kanzlei: In der Signatur hängt ein animiertes
/// Werbebild von mehreren Megabyte, das nicht unter jede Nachricht gehört.
/// Bisher wurde es dafür in Outlook von Hand aus dem Entwurf gelöscht. Hier ist
/// es ein Klick — und die Größe daneben sagt, warum er sich lohnt.
///
/// Ausgewählt heißt: geht mit. Die Signatur in den Einstellungen bleibt davon
/// unberührt; die Entscheidung gilt nur für diese eine Mail.
class EmailSignaturBilder extends StatelessWidget {
  final List<SignaturBild> bilder;

  /// Dateinamen, die für diese Mail weggelassen wurden.
  final List<String> weggelassen;

  final ValueChanged<String> onUmschalten;
  final bool aktiv;

  const EmailSignaturBilder({
    super.key,
    required this.bilder,
    required this.onUmschalten,
    this.weggelassen = const [],
    this.aktiv = true,
  });

  @override
  Widget build(BuildContext context) {
    if (bilder.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Bilder in der Signatur', style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'abwählen, was bei dieser Mail nicht mitgehen soll',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final bild in bilder)
              FilterChip(
                key: ValueKey(bild.dateiname),
                selected: !weggelassen.contains(bild.dateiname),
                onSelected: aktiv ? (_) => onUmschalten(bild.dateiname) : null,
                // Das Häkchen ist hier die ganze Auskunft: „geht mit". Ein
                // Bildsymbol daneben trüge nichts bei — jede Kachel dieser
                // Reihe ist ein Bild — und richtete Schaden an: Material
                // zeichnet das Häkchen einer ausgewählten Kachel **über** den
                // Avatar und legt dafür einen dunklen Schleier darüber. Der
                // stand dann dauerhaft auf jeder ausgewählten Kachel und sah
                // aus wie ein Zeiger, der auf allen zugleich steht.
                showCheckmark: true,
                label: Text(
                  '${bild.dateiname} · ${AnhangDarstellung.alsGroesse(bild.bytes)}',
                ),
                tooltip: weggelassen.contains(bild.dateiname)
                    ? 'Geht bei dieser Mail nicht mit'
                    : 'Geht mit der Signatur hinaus',
              ),
          ],
        ),
      ],
    );
  }
}
