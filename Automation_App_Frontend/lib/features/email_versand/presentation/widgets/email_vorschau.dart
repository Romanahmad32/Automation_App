import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/signatur_ansicht.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_zusammenfassung_zeile.dart';
import 'package:flutter/material.dart';

/// Die Mail, wie sie beim Empfänger ankommt (§4.7): Kopfzeilen, Anhänge unter
/// den Namen, unter denen sie hinausgehen, und der vollständige Text samt
/// Signatur — Text **und** Bilder.
///
/// Eigenes Widget, weil dieselbe Ansicht an zwei Stellen gebraucht wird — im
/// Vorschaufenster und in der Rückfrage vor dem Absenden. Sie nur in die
/// Rückfrage zu legen, hieße: Wer sich vergewissern will, muss erst auf
/// „Senden" drücken.
///
/// **Alles scrollt zusammen.** Vorher scrollte nur der Textblock; die Leiste
/// begann dann unter den Kopfzeilen und endete über dem Signaturhinweis, also
/// mitten in der Fläche, und sah aus, als gehöre sie zu nichts. Jetzt läuft sie
/// über die ganze Höhe am Rand — dafür bekommt dieses Widget von außen eine
/// begrenzte Höhe und füllt sie.
class EmailVorschau extends StatefulWidget {
  final EmailEntwurf entwurf;
  final String absender;

  /// Signaturblock aus den Einstellungen; leer, wenn keiner hinterlegt ist.
  final String signatur;

  /// Die formatierte Fassung derselben Signatur — sie wird gerendert, weil
  /// genau sie beim Empfänger ankommt.
  final String signaturHtml;

  /// Die Bilder der formatierten Signatur. Was der Anwalt für diese Mail
  /// abgewählt hat (`entwurf.ohneSignaturBilder`), fehlt hier genauso wie beim
  /// Empfänger.
  final List<SignaturBild> signaturBilder;

  /// True beim Entwurfsweg: Dort setzt Outlook seine eigene Signatur, die
  /// hinterlegte bleibt ungenutzt.
  final bool ohneSignatur;

  const EmailVorschau({
    super.key,
    required this.entwurf,
    required this.absender,
    this.signatur = '',
    this.signaturHtml = '',
    this.signaturBilder = const [],
    this.ohneSignatur = false,
  });

  @override
  State<EmailVorschau> createState() => _EmailVorschauState();
}

class _EmailVorschauState extends State<EmailVorschau> {
  /// Eigener Controller, damit die Leiste dauerhaft sichtbar sein darf: Eine
  /// Leiste, die erst beim Ziehen erscheint, beantwortet die Frage „ist da noch
  /// mehr?" nicht.
  final ScrollController _lauf = ScrollController();

  @override
  void dispose() {
    _lauf.dispose();
    super.dispose();
  }

  /// Die Signatur, wie sie unter dem Text steht — leer beim Entwurfsweg, wo
  /// Outlook seine eigene setzt.
  ///
  /// Sie steht als **eigener** Block unter dem Text und nicht mehr angehängt
  /// darin: Der Text ist reiner Text, die Signatur bringt Schrift, Größen und
  /// Farben mit. Beides in einer Zeichenkette zu vereinen, hiesse die
  /// Formatierung wegzuwerfen — genau das war der Grund, warum die Vorschau
  /// anders aussah als die versendete Mail.
  SignaturAnsicht get _signatur => SignaturAnsicht(
    text: widget.ohneSignatur ? '' : widget.signatur,
    html: widget.ohneSignatur ? '' : widget.signaturHtml,
    bilder: widget.signaturBilder,
    weggelassen: widget.entwurf.ohneSignaturBilder,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entwurf = widget.entwurf;
    final ohneHinterlegte =
        !widget.ohneSignatur && widget.signatur.trim().isEmpty;

    return Scrollbar(
      controller: _lauf,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _lauf,
        // Nur rechts, und nur so viel, wie die Leiste breit ist: Sie sitzt
        // damit am Rand der Fläche statt in ihr.
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmailZusammenfassungZeile(
              beschriftung: 'Von',
              werte: [
                widget.absender.isEmpty
                    ? '— kein Postfach-Zugang —'
                    : widget.absender,
              ],
            ),
            EmailZusammenfassungZeile(
              beschriftung: 'An',
              werte: entwurf.an.isEmpty
                  ? const ['— noch keiner —']
                  : entwurf.an,
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
            SelectableText(entwurf.text, style: theme.textTheme.bodyMedium),
            if (_signatur.hatInhalt) ...[const SizedBox(height: 14), _signatur],
            const SizedBox(height: 10),
            Text(
              _signaturHinweis(ohneHinterlegte),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sagt ausdrücklich, wenn keine Signatur hinterlegt ist. Ohne diesen Satz
  /// fehlt sie in der Vorschau, ohne dass etwas darauf hinweist — und der
  /// Anwalt merkt es erst an der versendeten Mail.
  String _signaturHinweis(bool ohneHinterlegte) {
    if (widget.ohneSignatur) {
      return 'Die Signatur setzt Outlook selbst ein; sie steht deshalb nicht '
          'in dieser Vorschau.';
    }
    if (ohneHinterlegte) {
      return 'Es ist keine Signatur hinterlegt — sie lässt sich in den '
          'Einstellungen aus Outlook übernehmen.';
    }
    if (widget.signaturHtml.trim().isEmpty) {
      return 'Die Signatur stammt aus den Einstellungen und geht als reiner '
          'Text mit hinaus — eine formatierte Fassung ist nicht übernommen.';
    }
    return 'Die Signatur stammt aus den Einstellungen und geht so mit hinaus. '
        'Outlook zeichnet Mails mit dem Word-Modul, deshalb kann diese '
        'Ansicht nah herankommen, aber nicht pixelgleich sein.';
  }
}
