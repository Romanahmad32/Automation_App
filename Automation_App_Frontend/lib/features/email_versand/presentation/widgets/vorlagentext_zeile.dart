import 'package:automation_app/features/email_versand/domain/entities/platzhalter_befund.dart';
import 'package:flutter/material.dart';

/// Eine Zeile der Gegenüberstellung: links die Vorlage, wie sie hinterlegt ist,
/// rechts das Ergebnis (§4.7).
///
/// **Die rechte Spalte ist der Zweck dieses Widgets.** Der Vorlagentext allein
/// sagt dem Anwalt nichts Neues — er hat ihn geschrieben. Erst daneben zu
/// sehen, was daraus wurde („entfällt"), führt einen gefüllten Text auf seine
/// Vorlage zurück.
class VorlagentextZeile extends StatelessWidget {
  /// Zeilennummer, von 1 an. **0 ist die Betreffzeile** — sie hat keine.
  final int nummer;

  /// Die Zeile, wie sie in der Vorlage steht.
  final String vorlage;

  /// Was daraus wurde; **null heißt: die Zeile entfällt**.
  final String? ergebnis;

  /// Die leer gebliebenen Platzhalter dieser Zeile — sie benennen den Grund.
  final List<PlatzhalterBefund> leere;

  const VorlagentextZeile({
    super.key,
    required this.nummer,
    required this.vorlage,
    this.ergebnis,
    this.leere = const [],
  });

  bool get _entfaellt => ergebnis == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final einfarbig = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
    );
    final gedaempft = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontStyle: FontStyle.italic,
    );

    return Container(
      color: _entfaellt
          ? theme.colorScheme.tertiary.withValues(alpha: 0.08)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              nummer == 0 ? '' : '$nummer',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              vorlage.isEmpty ? ' ' : vorlage,
              style: einfarbig,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _entfaellt
                ? Text(_grund(), style: gedaempft)
                : SelectableText(
                    ergebnis!.isEmpty ? ' ' : ergebnis!,
                    style: theme.textTheme.bodySmall,
                  ),
          ),
        ],
      ),
    );
  }

  /// Warum die Zeile entfällt — mit Namen, wenn es einen gibt. Ohne die Namen
  /// stünde dort nur „entfällt", und der Anwalt müsste die Zeile selbst lesen.
  String _grund() {
    if (leere.isEmpty) return 'entfällt';
    final namen = leere.map((befund) => befund.geschrieben).join(', ');
    return 'entfällt — $namen ohne Wert';
  }
}
