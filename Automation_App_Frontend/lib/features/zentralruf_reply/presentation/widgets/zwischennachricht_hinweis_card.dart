import 'package:automation_app/features/zentralruf_reply/presentation/widgets/tone_card.dart';
import 'package:flutter/material.dart';

/// Hinweiskarte im Übernahme-Formular für Zwischennachrichten des Zentralrufs:
/// erklärt, dass die endgültige Antwort in einer weiteren Mail folgt und die
/// Übernahme im Normalfall warten sollte.
class ZwischennachrichtHinweisCard extends StatelessWidget {
  const ZwischennachrichtHinweisCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ToneCard(
      accent: Theme.of(context).colorScheme.tertiary,
      icon: Icons.hourglass_top,
      text:
          'Dies ist eine Zwischennachricht des Zentralrufs — die Auskunft war '
          'nicht sofort möglich, die endgültige Antwort folgt in einer '
          'weiteren E-Mail. Im Normalfall bitte abwarten; eine Übernahme ist '
          'erst möglich, wenn unten ein Versicherer eingetragen wird.',
    );
  }
}
