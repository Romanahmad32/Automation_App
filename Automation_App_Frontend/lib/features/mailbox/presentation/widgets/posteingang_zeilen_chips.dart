import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:flutter/material.dart';

/// Die Chip-Reihe unter Betreff und Absender einer Posteingangszeile: der
/// Vorgangsbezug, die Zentralruf-Markierung und die Büroklammer mit
/// Anzahl (Issue #134).
class PosteingangZeilenChips extends StatelessWidget {
  const PosteingangZeilenChips({
    super.key,
    this.bezug,
    this.zentralruf,
    this.anzahlAnhaenge = 0,
  });

  final Vorgangsbezug? bezug;

  /// null = keine erfasste Antwort; sonst true = übernommen, false = offen.
  final bool? zentralruf;
  final int anzahlAnhaenge;

  /// Ocker — bewusst außerhalb des Farbschemas, damit die Zentralruf-Pille
  /// unabhängig vom Kanzlei-Theme immer dieselbe, wiedererkennbare Farbe hat.
  static const Color zentralrufFarbe = Color(0xFFB8860B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[
      if (bezug != null) _vorgangsPille(theme),
      if (zentralruf != null) _zentralrufPille(),
      if (anzahlAnhaenge > 0) _buerklammer(theme),
    ];
    return chips.isEmpty
        ? const SizedBox.shrink()
        : Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  StatusPille _vorgangsPille(ThemeData theme) {
    final sicher = bezug!.sicherheit == BezugSicherheit.sicher;
    return StatusPille(
      text: sicher ? bezug!.vorgang.zeichen : '~ ${bezug!.vorgang.zeichen}',
      farbe: sicher ? theme.colorScheme.primary : theme.colorScheme.tertiary,
      tooltip: bezug!.grund,
    );
  }

  StatusPille _zentralrufPille() => StatusPille(
    text: zentralruf! ? 'Zentralruf · übernommen' : 'Zentralruf · offen',
    farbe: zentralrufFarbe,
  );

  Widget _buerklammer(ThemeData theme) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.attach_file, size: 14, color: theme.colorScheme.outline),
      const SizedBox(width: 2),
      Text(
        '$anzahlAnhaenge',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    ],
  );
}
