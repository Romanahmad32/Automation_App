import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
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

  /// Die formatierte Fassung — sie wird gerendert.
  final String signaturHtml;

  final List<SignaturBild> signaturBilder;

  const EmailVorschauDialog({
    super.key,
    required this.entwurf,
    required this.absender,
    this.signatur = '',
    this.signaturHtml = '',
    this.signaturBilder = const [],
  });

  static Future<void> zeigen(
    BuildContext context, {
    required EmailEntwurf entwurf,
    required String absender,
    String signatur = '',
    String signaturHtml = '',
    List<SignaturBild> signaturBilder = const [],
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => EmailVorschauDialog(
        entwurf: entwurf,
        absender: absender,
        signatur: signatur,
        signaturHtml: signaturHtml,
        signaturBilder: signaturBilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vorschau'),
      // Feste Höhe: Die Vorschau bringt ihre eigene Bildlaufleiste mit und
      // füllt, was sie bekommt. Ohne Grenze schöbe ein langes Anschreiben die
      // Schaltfläche aus dem Fenster.
      content: SizedBox(
        width: 560,
        height: 420,
        child: EmailVorschau(
          entwurf: entwurf,
          absender: absender,
          signatur: signatur,
          signaturHtml: signaturHtml,
          signaturBilder: signaturBilder,
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
