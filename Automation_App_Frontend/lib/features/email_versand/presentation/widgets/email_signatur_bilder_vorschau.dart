import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/utils/signatur_bild_quelle.dart';
import 'package:flutter/material.dart';

/// Die Bilder der Signatur, so wie sie unter der Mail stehen werden (§4.7).
///
/// Die Vorschau zeigte lange nur den Signatur**text**. Das ist Outlooks eigene
/// Nur-Text-Übersetzung — richtig als Alternative für Empfänger ohne HTML, aber
/// eben nicht das, was die meisten sehen: Unter deren Mail steht das Logo. Wer
/// nur den Text sieht, prüft die halbe Signatur und erfährt vom Rest erst im
/// Ordner „Gesendet".
///
/// Gezeigt wird, was bei **dieser** Mail mitgeht: Ein für sie abgewähltes Bild
/// fehlt hier genauso wie beim Empfänger. Schrift und Farben der HTML-Fassung
/// bleiben ungezeigt — sie gehören Outlook, und ein ungefähres Nachbilden wäre
/// eine Vorschau, die etwas anderes behauptet als die Mail.
class EmailSignaturBilderVorschau extends StatelessWidget {
  /// Alle Bilder der hinterlegten Signatur.
  final List<SignaturBild> bilder;

  /// Dateinamen, die für diese Mail weggelassen wurden.
  final List<String> weggelassen;

  /// Höhe, auf die ein Bild höchstens gebracht wird.
  final double maxHoehe;

  /// Name der Outlook-Signatur, solange sie nur gelesen und noch nicht
  /// gespeichert ist; sonst leer. Siehe [SignaturBildQuelle].
  final String ausOutlook;

  const EmailSignaturBilderVorschau({
    super.key,
    required this.bilder,
    this.weggelassen = const [],
    this.maxHoehe = 90,
    this.ausOutlook = '',
  });

  @override
  Widget build(BuildContext context) {
    final mitgehend = bilder
        .where((bild) => !weggelassen.contains(bild.dateiname))
        .toList();
    if (mitgehend.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final bild in mitgehend)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHoehe, maxWidth: 320),
              child: Image.network(
                // Die Marke gehört an die Adresse: Ohne sie hält Flutter unter
                // demselben `image001.png` das Logo der vorigen Signatur fest.
                SignaturBildQuelle.fuer(
                  bild.dateiname,
                  marke: bild.marke,
                  ausOutlook: ausOutlook,
                ),
                fit: BoxFit.contain,
                // Ein Bild, das der Dienst nicht ausliefert, darf die Vorschau
                // nicht mit einem Ausrufezeichen füllen: Es geht trotzdem
                // hinaus, nur die Anzeige hier scheitert. Der Dateiname sagt
                // dann wenigstens, worum es ging.
                errorBuilder: (context, _, _) => _ersatz(context, bild),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ersatz(BuildContext context, SignaturBild bild) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 6),
        Text(
          bild.dateiname,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
