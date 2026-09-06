import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:flutter/material.dart';

/// Dezenter Badge fuer die Vorlagenuebersicht — welche Auflistungs-Version
/// hinterlegt ist und, seit #104 Stufe 4, der Stand der Vorlage
/// (`VorlagenStandKennzeichen` baut darauf auf).
/// Nutzt [SoftTone], damit der Hintergrund im Light-Mode hell getoent bleibt
/// (statt der fast schwarzen `*Container`-Farben des Themes).
///
/// Der Text bleibt **einzeilig und kuerzt notfalls**: Der Badge steht in einer
/// Tabellenspalte, die bei angehobener Schrift (Issue #57) schmal wird — ein
/// zweizeiliger Badge liesse die ganze Zeile springen. Umbrechen darf statt
/// dessen die Zeile darum (`Wrap`).
class AuflistungBadge extends StatelessWidget {
  final String label;
  final Color accent;

  /// Ein kleines Zeichen vor der Aufschrift — null laesst den Badge wie bisher
  /// nur den Text tragen.
  final IconData? icon;

  const AuflistungBadge({
    super.key,
    required this.label,
    required this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = SoftTone.fromAccent(accent, theme.colorScheme);
    final stil = theme.textTheme.labelSmall?.copyWith(
      color: tone.foreground,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (icon case final zeichen?)
            Icon(zeichen, size: 14, color: tone.foreground),
          Flexible(
            child: Text(
              label,
              style: stil,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
