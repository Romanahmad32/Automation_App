import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:flutter/material.dart';

/// Ein Jahrgang in der Chip-Zeile über dem Register: `2018 ✓`,
/// `2021 ✗ fehlt`, `2022 ⚠ 2 Lücken`.
///
/// Der Chip **zeigt nur an** — er ist kein zweiter Filter. Ein Klick setzt den
/// Jahrgang der Filterleiste darunter, damit „2021 fehlt" und „zeig mir 2021"
/// nicht zwei Bedienwege sind.
class JahrgangStandChip extends StatelessWidget {
  final int jahrgang;

  /// Der übernommene Stand; null heißt: dieser Jahrgang fehlt ganz.
  final JahrgangStand? stand;

  /// Ob der Jahrgangsfilter gerade auf diesem Jahrgang steht.
  final bool ausgewaehlt;

  final VoidCallback? onTap;

  const JahrgangStandChip({
    super.key,
    required this.jahrgang,
    this.stand,
    this.ausgewaehlt = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final akzent = _akzent(scheme);
    final ton = SoftTone.fromAccent(akzent, scheme);
    final beschriftung = _beschriftung();

    return Tooltip(
      message: _tooltip(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ton.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ausgewaehlt ? akzent : ton.border,
                width: ausgewaehlt ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Text(
                  '$jahrgang',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: ton.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(_symbol(), size: 16, color: ton.foreground),
                if (beschriftung.isNotEmpty)
                  Text(
                    beschriftung,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ton.foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Grün gibt es hier nicht als Theme-Rolle — `primary` steht für „in
  /// Ordnung", `error` für „fehlt ganz", `tertiary` für „übernommen, aber mit
  /// offenen Lücken".
  Color _akzent(ColorScheme scheme) {
    if (stand == null) return scheme.error;
    return stand!.vollstaendig ? scheme.primary : scheme.tertiary;
  }

  IconData _symbol() {
    if (stand == null) return Icons.close;
    return stand!.vollstaendig ? Icons.check : Icons.warning_amber_rounded;
  }

  String _beschriftung() {
    if (stand == null) return 'fehlt';
    final luecken = stand!.luecken.length;
    if (luecken == 0) return '';
    return luecken == 1 ? '1 Lücke' : '$luecken Lücken';
  }

  String _tooltip() {
    if (stand == null) {
      return 'Jahrgang $jahrgang ist noch nicht übernommen — er liegt '
          'zwischen zwei übernommenen Jahrgängen.';
    }
    final saetze = <String>[
      '${stand!.zeilen} Zeilen, höchste Nummer ${stand!.hoechsteNummer}.',
      if (stand!.luecken.isNotEmpty)
        'Fehlende Nummern: ${stand!.luecken.join(', ')}.',
      if (stand!.mitBefund > 0) '${stand!.mitBefund} Zeilen mit Befund.',
    ];
    return saetze.join('\n');
  }
}
