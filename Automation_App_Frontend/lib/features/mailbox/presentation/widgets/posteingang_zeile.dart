import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/mailbox/presentation/utils/posteingang_absender.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_zeilen_chips.dart';
import 'package:flutter/material.dart';

/// Eine Zeile der Posteingangsliste: Absender (fett bei ungelesen, mit einem
/// Punkt links), Betreff, Chips — rechts nur die Uhrzeit, das Datum steht im
/// Gruppenkopf darüber (Issue #134).
class PosteingangZeile extends StatelessWidget {
  const PosteingangZeile({
    super.key,
    required this.eintrag,
    required this.ausgewaehlt,
    required this.onTap,
    this.bezug,
    this.zentralruf,
  });

  final PosteingangEintrag eintrag;
  final bool ausgewaehlt;
  final VoidCallback onTap;
  final Vorgangsbezug? bezug;

  /// null = keine erfasste Antwort; sonst true = übernommen, false = offen.
  final bool? zentralruf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ungelesen = !eintrag.gelesen;
    return Material(
      color: ausgewaehlt
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _mitte(theme, ungelesen)),
              const SizedBox(width: 12),
              Text(
                eintrag.datum == null ? '' : deutscheUhrzeit(eintrag.datum!),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mitte(ThemeData theme, bool ungelesen) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (ungelesen) _ungelesenPunkt(theme),
          Expanded(
            child: Text(
              posteingangEintragAbsender(eintrag),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ungelesen
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
      Text(
        eintrag.betreff,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      PosteingangZeilenChips(
        bezug: bezug,
        zentralruf: zentralruf,
        anzahlAnhaenge: eintrag.anzahlAnhaenge,
      ),
    ],
  );

  Widget _ungelesenPunkt(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
      ),
    ),
  );
}
