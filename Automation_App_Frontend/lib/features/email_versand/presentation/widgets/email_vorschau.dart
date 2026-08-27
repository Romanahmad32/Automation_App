import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_zusammenfassung_zeile.dart';
import 'package:flutter/material.dart';

/// Die Mail, wie sie beim Empfänger ankommt (§4.7): Kopfzeilen, Anhänge unter
/// den Namen, unter denen sie hinausgehen, und der vollständige Text samt
/// Signatur.
///
/// Eigenes Widget, weil dieselbe Ansicht an zwei Stellen gebraucht wird — im
/// Vorschaufenster und in der Rückfrage vor dem Absenden. Sie nur in die
/// Rückfrage zu legen, hieße: Wer sich vergewissern will, muss erst auf
/// „Senden" drücken.
class EmailVorschau extends StatelessWidget {
  final EmailEntwurf entwurf;
  final String absender;

  /// Signaturblock aus den Einstellungen; leer, wenn keiner hinterlegt ist.
  final String signatur;

  /// True beim Entwurfsweg: Dort setzt Outlook seine eigene Signatur, die
  /// hinterlegte bleibt ungenutzt.
  final bool ohneSignatur;

  const EmailVorschau({
    super.key,
    required this.entwurf,
    required this.absender,
    this.signatur = '',
    this.ohneSignatur = false,
  });

  /// Der vollständige Text, wie ihn der Empfänger sieht.
  String get volltext {
    final block = signatur.trim();
    if (ohneSignatur || block.isEmpty) return entwurf.text;
    return '${entwurf.text.trimRight()}\n\n$block';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ohneHinterlegte = !ohneSignatur && signatur.trim().isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmailZusammenfassungZeile(
          beschriftung: 'Von',
          werte: [absender.isEmpty ? '— kein Postfach-Zugang —' : absender],
        ),
        EmailZusammenfassungZeile(
          beschriftung: 'An',
          werte: entwurf.an.isEmpty ? const ['— noch keiner —'] : entwurf.an,
        ),
        if (entwurf.kopie.isNotEmpty)
          EmailZusammenfassungZeile(
            beschriftung: 'Kopie',
            werte: entwurf.kopie,
          ),
        EmailZusammenfassungZeile(
          beschriftung: 'Betreff',
          werte: [
            entwurf.betreff.isEmpty ? '— noch keiner —' : entwurf.betreff,
          ],
        ),
        EmailZusammenfassungZeile(
          beschriftung: 'Anhänge',
          werte: entwurf.anhangPfade.isEmpty
              ? const ['— keine —']
              : entwurf.anhangPfade.map(entwurf.nameVon).toList(),
        ),
        const Divider(height: 20),
        // Scrollbar begrenzt: Ein langes Anschreiben darf die Schaltflächen
        // nicht aus dem Fenster schieben.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: SingleChildScrollView(
            child: SelectableText(volltext, style: theme.textTheme.bodyMedium),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _signaturHinweis(ohneHinterlegte),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// Sagt ausdrücklich, wenn keine Signatur hinterlegt ist. Ohne diesen Satz
  /// fehlt sie in der Vorschau, ohne dass etwas darauf hinweist — und der
  /// Anwalt merkt es erst an der versendeten Mail.
  String _signaturHinweis(bool ohneHinterlegte) {
    if (ohneSignatur) {
      return 'Die Signatur setzt Outlook selbst ein; sie steht deshalb nicht '
          'in dieser Vorschau.';
    }
    if (ohneHinterlegte) {
      return 'Es ist keine Signatur hinterlegt — sie lässt sich in den '
          'Einstellungen aus Outlook übernehmen.';
    }
    return 'Die Signatur stammt aus den Einstellungen und geht so mit hinaus.';
  }
}
