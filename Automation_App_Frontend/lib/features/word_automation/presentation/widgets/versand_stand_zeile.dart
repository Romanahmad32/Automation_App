import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/versand_eintrag_zeile.dart';
import 'package:flutter/material.dart';

/// Sagt im Abschlussdialog, was die App zu diesem Vorgang schon versendet hat
/// (§4.7). Der Satz begründet das vorbelegte Häkchen: Ein Kreuz, das ohne
/// Erklärung gesetzt ist, wird nicht gelesen, sondern geglaubt.
///
/// Gelesen wird das **Protokoll**, nicht mehr nur der Versand dieser Sitzung:
/// Wer das Schreiben vorige Woche verschickt und den Vorgang heute abschließt,
/// hat vorher ein leeres Feld vorgefunden — und musste das Häkchen aus dem
/// Gedächtnis setzen, obwohl die App es besser wusste.
class VersandStandZeile extends StatelessWidget {
  /// Alle Versände zu diesem Vorgang, der jüngste zuerst; leer, solange noch
  /// nichts hinausging.
  final List<VersandEintrag> eintraege;

  /// True, solange das Protokoll noch geladen wird.
  final bool laedt;

  const VersandStandZeile({
    super.key,
    this.eintraege = const [],
    this.laedt = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (laedt) {
      return const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Versandstand wird geladen…'),
        ],
      );
    }

    if (eintraege.isEmpty) {
      return Text(
        'Die App hat zu diesem Vorgang noch nichts versendet:',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final weitere = eintraege.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VersandEintragZeile(eintrag: eintraege.first),
        if (weitere > 0)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 2),
            child: Text(
              weitere == 1
                  ? 'Ein weiterer Versand zu diesem Vorgang.'
                  : '$weitere weitere Versände zu diesem Vorgang.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }
}
