import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorlagen_stand.dart';
import 'package:flutter/material.dart';

/// Eine Zeile Klartext zu einer Vollmachtsvorlage: Art, Dateiname und ob die
/// App sie findet — nach dem Muster der `OrdnerZustandZeile`.
class VollmachtVorlageZeile extends StatelessWidget {
  final VollmachtVorlage vorlage;

  const VollmachtVorlageZeile({super.key, required this.vorlage});

  /// Der Satz zu [vorlage], im Test ohne Widget nachlesbar.
  static String satz(VollmachtVorlage vorlage) {
    final titel = vorlage.art?.titel ?? 'Unbekannte Art';
    final geaendert = vorlage.geaendertAm;
    if (!vorlage.vorhanden) {
      return '$titel: „${vorlage.dateiname}“ fehlt — diese Vollmacht lässt '
          'sich nicht drucken.';
    }
    return geaendert == null
        ? '$titel: „${vorlage.dateiname}“ vorhanden'
        : '$titel: „${vorlage.dateiname}“ vorhanden, geändert am '
              '${deutschesDatum(geaendert)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = vorlage.vorhanden
        ? theme.colorScheme.outline
        : theme.colorScheme.tertiary;
    return Row(
      children: [
        Icon(
          vorlage.vorhanden ? Icons.check_circle_outline : Icons.help_outline,
          size: 16,
          color: farbe,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            satz(vorlage),
            style: theme.textTheme.bodySmall?.copyWith(color: farbe),
          ),
        ),
      ],
    );
  }
}
