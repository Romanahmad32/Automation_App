import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/utils/signatur_html_aufbereitung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_signatur_bilder_vorschau.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

/// Die Signatur, wie sie unter der Mail steht (§4.7) — die **formatierte**
/// Fassung, gerendert.
///
/// Outlook führt die Signatur doppelt: als HTML mit Schrift, Größen und Farben,
/// und daneben als eigene Nur-Text-Übersetzung. Die Mail trägt beide, das
/// Programm des Empfängers nimmt die erste. Die Vorschau zeigte lange die
/// zweite — und damit etwas anderes, als beim Empfänger ankommt, ohne dass ein
/// Fehler vorlag.
///
/// **Was hier trotzdem nicht steht:** Outlook zeichnet HTML-Mails mit dem
/// Word-Modul, nicht mit einem Browser. Diese Ansicht kommt nah heran, wird
/// aber nie pixelgleich sein — sie zeigt die Signatur so, wie ein gewöhnliches
/// Mailprogramm sie zeigt.
class SignaturAnsicht extends StatelessWidget {
  /// Die Nur-Text-Fassung — der Rückfall, wenn keine formatierte übernommen ist.
  final String text;

  /// Die formatierte Fassung; leer, wenn es keine gibt.
  final String html;

  final List<SignaturBild> bilder;

  /// Dateinamen, die bei dieser Mail nicht mitgehen.
  final List<String> weggelassen;

  const SignaturAnsicht({
    super.key,
    this.text = '',
    this.html = '',
    this.bilder = const [],
    this.weggelassen = const [],
  });

  /// True, wenn überhaupt etwas anzuzeigen ist.
  bool get hatInhalt => html.trim().isNotEmpty || text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aufbereitet = SignaturHtmlAufbereitung.fuerAnzeige(
      html,
      weggelassen: weggelassen,
    );

    if (aufbereitet.isEmpty) {
      // Ohne formatierte Fassung geht der Text hinaus, und genau der steht
      // dann hier — samt der Bilder, die es ohne HTML zwar selten gibt, die
      // aber mitgehen würden.
      if (text.trim().isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(text.trim(), style: theme.textTheme.bodyMedium),
          EmailSignaturBilderVorschau(bilder: bilder, weggelassen: weggelassen),
        ],
      );
    }

    return HtmlWidget(
      aufbereitet,
      // Die Signatur bringt ihre Schriftgrößen selbst mit; ohne diese Grundlage
      // erbte sie die des Mailtextes darüber und sähe größer aus als beim
      // Empfänger.
      textStyle: const TextStyle(fontSize: 11, height: 1.2),
      // Ein Bild, das der Dienst nicht ausliefert, darf die Vorschau nicht mit
      // einem Ausrufezeichen füllen: Es geht trotzdem hinaus.
      onErrorBuilder: (_, _, _) => const SizedBox.shrink(),
      onLoadingBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
