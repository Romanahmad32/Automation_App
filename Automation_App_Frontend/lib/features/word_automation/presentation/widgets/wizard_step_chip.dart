import 'package:flutter/material.dart';

/// Ein Schritt in der Schrittleiste des Wizards: nummerierter Kreis plus
/// Titel. Erreichbare Schritte sind anklickbar, noch nicht freigeschaltete
/// erscheinen gedämpft und ohne [onTap].
class WizardStepChip extends StatelessWidget {
  const WizardStepChip({
    super.key,
    required this.number,
    required this.title,
    required this.isActive,
    required this.isEnabled,
    required this.showTitle,
    this.onTap,
  });

  final int number;
  final String title;
  final bool isActive;
  final bool isEnabled;

  /// Ob der Titel neben der Ziffer steht. `false` lässt nur den Kreis stehen
  /// — für nicht aktive Schritte, wenn `WizardStepBar` mit vollen Titeln
  /// sonst rechts überliefe (Issue #57): Bei ausgeklappter Sidebar reichte
  /// die Breite für drei/vier volle Titel samt Trennlinien nicht mehr.
  final bool showTitle;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final circleColor = isActive
        ? colorScheme.primary
        : isEnabled
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final numberColor = isActive
        ? colorScheme.onPrimary
        : isEnabled
        ? colorScheme.onPrimaryContainer
        : colorScheme.outline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: circleColor,
              // Theme-Rolle statt nacktem [TextStyle]: `CircleAvatar` setzt
              // sonst `titleMedium` als Vorgabe, und die Ziffer sprengte den
              // Kreis, sobald die Schriftskala steigt (Issue #57).
              child: Text(
                '$number',
                style: theme.textTheme.labelLarge?.copyWith(color: numberColor),
              ),
            ),
            if (showTitle) ...[
              const SizedBox(width: 8),
              // Der Schritt-Titel las bisher die Vorgabe aus dem umgebenden
              // [DefaultTextStyle] — also `bodyMedium`, nur eben ohne den
              // Theme-Bezug, an dem man das sieht. Jetzt steht die Rolle da.
              //
              // `Flexible` + Ellipsis ist das Sicherheitsnetz, falls
              // `WizardStepBar` dem Chip trotz ihrer eigenen Breitenrechnung
              // einmal zu wenig Platz zuteilt (Issue #57) — dann kürzt der
              // Titel sich selbst, statt die Zeile zu sprengen.
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isEnabled ? null : colorScheme.outline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
