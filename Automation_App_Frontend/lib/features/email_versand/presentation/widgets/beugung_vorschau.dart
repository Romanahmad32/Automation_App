import 'package:automation_app/features/email_versand/domain/entities/beugung.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:flutter/material.dart';

/// Was die Beugungen einer Vorlage ergeben — im Editor, während geschrieben
/// wird (§4.7, ergänzt am 02.09.2026).
///
/// **Nicht der ganze Text dreimal gefüllt.** Das wäre im Editor irreführend:
/// Dort ist kein Vorgang gewählt, jeder Vorgangsplatzhalter bliebe leer, und
/// nach der Regel „Zeile ohne gefüllten Platzhalter entfällt" stünde von der
/// Vorlage kaum etwas da. Was die Vorschau hier leisten kann, ist die eine
/// Auskunft, die **nur** an den Formen hängt — und die steht damit vollständig.
///
/// Der eigentliche Gewinn ist die dritte Spalte: Die neutrale Form ist meist
/// **errechnet**, und ob „Mandant(in)" so in der Mail stehen soll, sieht der
/// Anwalt sonst erst an einer Mail zu einem Mandanten ohne hinterlegte
/// Anredeart — also selten und spät.
class BeugungVorschau extends StatelessWidget {
  final List<Beugung> beugungen;

  const BeugungVorschau({super.key, required this.beugungen});

  @override
  Widget build(BuildContext context) {
    if (beugungen.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(
          'Beugungen in dieser Vorlage (${beugungen.length})',
          style: theme.textTheme.labelLarge,
        ),
        for (final beugung in beugungen) BeugungVorschauZeile(beugung: beugung),
        if (beugungen.any((beugung) => !beugung.neutralGeschrieben))
          Text(
            'Wo „errechnet" steht, hat die Vorlage nur zwei Formen. Eine '
            'dritte schreibt sich oft schöner — '
            '{{Mandant/Mandantin/Mandantschaft}}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Eine Beugung mit ihren drei Formen. Die Beschriftungen kommen aus [Anrede]
/// selbst, damit hier dieselben Wörter stehen wie auf den Chips im
/// Versanddialog.
class BeugungVorschauZeile extends StatelessWidget {
  final Beugung beugung;

  const BeugungVorschauZeile({super.key, required this.beugung});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            beugung.geschrieben,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            formenText(beugung),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Die drei Formen als eine Zeile. Öffentlich, weil ein Test darauf zeigt:
  /// Dass „errechnet" **nur** an einer errechneten Form steht, ist die Zusage
  /// dieser Vorschau.
  static String formenText(Beugung beugung) {
    final teile = [
      for (final anrede in Anrede.values)
        '${anrede.displayName}: ${beugung.formFuer(anrede)}'
            '${anrede == Anrede.keine && !beugung.neutralGeschrieben ? ' (errechnet)' : ''}',
    ];
    return teile.join('  ·  ');
  }
}
