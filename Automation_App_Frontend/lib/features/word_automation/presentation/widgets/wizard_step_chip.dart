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
    this.onTap,
  });

  final int number;
  final String title;
  final bool isActive;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              child: Text('$number', style: TextStyle(color: numberColor)),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isEnabled ? null : colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
