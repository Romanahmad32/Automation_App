import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/presentation/utils/versand_darstellung.dart';
import 'package:flutter/material.dart';

/// Ein Eintrag des Versandprotokolls als Zeile (§4.7).
///
/// Der Haken ist grün nur beim Direktversand: Nur dort hat die App die
/// Einlieferung gesehen. Eine Übergabe an Outlook trägt deshalb ein anderes
/// Zeichen — ein Protokoll, das beides gleich aussehen lässt, wäre als
/// Nachweis schlechter als keines.
class VersandEintragZeile extends StatelessWidget {
  final VersandEintrag eintrag;

  /// Zeigt Betreff, Anhänge und Ablageort zusätzlich — im Protokollfenster,
  /// wo Platz dafür ist. In der Übersicht bleibt es bei der einen Zeile.
  final bool ausfuehrlich;

  const VersandEintragZeile({
    super.key,
    required this.eintrag,
    this.ausfuehrlich = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nachweis = eintrag.weg.istNachweis;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          nachweis ? Icons.check_circle : Icons.outbox_outlined,
          size: 20,
          color: nachweis ? Colors.green : theme.colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                VersandDarstellung.kurz(eintrag),
                style: theme.textTheme.bodyMedium,
              ),
              if (ausfuehrlich) ..._einzelheiten(theme),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _einzelheiten(ThemeData theme) {
    final zeilen = <String>[
      if (eintrag.betreff.isNotEmpty) 'Betreff: ${eintrag.betreff}',
      if (eintrag.anhaenge.isNotEmpty)
        'Anhänge: ${eintrag.anhaenge.join(', ')}',
      if (eintrag.absender.isNotEmpty) 'Von: ${eintrag.absender}',
      ?VersandDarstellung.ablage(eintrag),
    ];

    return [
      const SizedBox(height: 2),
      for (final zeile in zeilen)
        Text(
          zeile,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
    ];
  }
}
