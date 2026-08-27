import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:flutter/material.dart';

/// Wie schwer die Nachricht ist und wie viel das Postfach durchlässt (§4.7).
///
/// Die Grenze prüft der Dienst ohnehin — aber erst beim Senden, also nach dem
/// einen unumkehrbaren Klick. Was dann kommt, ist eine abgewiesene Nachricht
/// und eine Fehlermeldung des fremden Servers. Hier steht die Zahl, während der
/// Anwalt anhängt, und er sieht beim Anhängen des Gutachtens, dass es eng wird.
///
/// Gezählt wird die **ganze** Nachricht, nicht nur die Anhänge: Die Bilder der
/// Signatur gehen im selben Umschlag hinaus.
class EmailGroesseZeile extends StatelessWidget {
  final int gesamtBytes;

  /// Grenze in Bytes; null, solange der Dienst nicht geantwortet hat.
  final int? maxBytes;

  const EmailGroesseZeile({
    super.key,
    required this.gesamtBytes,
    this.maxBytes,
  });

  @override
  Widget build(BuildContext context) {
    final grenze = maxBytes;
    if (grenze == null || grenze <= 0 || gesamtBytes == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final anteil = gesamtBytes / grenze;
    final zuGross = gesamtBytes > grenze;
    // Ab drei Vierteln lohnt der Hinweis: Ein Gutachten mehr, und es reicht
    // nicht.
    final knapp = !zuGross && anteil >= 0.75;

    final farbe = zuGross
        ? theme.colorScheme.error
        : knapp
        ? theme.colorScheme.tertiary
        : theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: anteil.clamp(0.0, 1.0),
            minHeight: 4,
            color: farbe,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 6),
          Text(
            _text(zuGross, knapp, grenze),
            style: theme.textTheme.bodySmall?.copyWith(color: farbe),
          ),
        ],
      ),
    );
  }

  String _text(bool zuGross, bool knapp, int grenze) {
    final gross = AnhangDarstellung.alsGroesse(gesamtBytes);
    final maximal = AnhangDarstellung.alsGroesse(grenze);
    if (zuGross) {
      return 'Die Nachricht ist mit $gross zu groß — das Postfach lässt '
          '$maximal durch. Weniger anhängen, die Dateien verkleinern oder ein '
          'Bild aus der Signatur weglassen.';
    }
    if (knapp) {
      return 'Nachricht: $gross von $maximal — es wird knapp.';
    }
    return 'Nachricht: $gross von $maximal';
  }
}
