import 'package:flutter/material.dart';

class SidebarItem extends StatelessWidget {
  const SidebarItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.isExtended,
    required this.animationDuration,
    required this.collapsedWidth,
    required this.onTap,
  });

  final Widget icon;
  final Widget selectedIcon;
  final String label;
  final bool isSelected;
  final bool isExtended;
  final Duration animationDuration;
  final double collapsedWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bgColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.15)
        : Colors.transparent;
    final fgColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedContainer(
        duration: animationDuration,
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                SizedBox(
                  width: collapsedWidth - 18,
                  child: IconTheme(
                    data: IconThemeData(color: fgColor),
                    child: Center(child: isSelected ? selectedIcon : icon),
                  ),
                ),
                // Flexible statt eines unbeschränkten Row-Kindes: Ohne das
                // misst Align die Beschriftung in ihrer natürlichen Breite
                // und reicht sie ungekürzt an die Row weiter — das Ellipsis
                // am Text greift dann nie, weil ihm nie ein Maximum vorgegeben
                // wird. Erst Flexible zwingt die verbleibende Row-Breite als
                // echtes Maximum durch (locker, damit die Einklapp-Animation
                // weiter bis auf 0 schrumpfen kann).
                Flexible(
                  child: ClipRect(
                    child: AnimatedAlign(
                      duration: animationDuration,
                      curve: Curves.easeInOut,
                      alignment: Alignment.centerLeft,
                      widthFactor: isExtended ? 1 : 0,
                      child: Text(
                        label,
                        style: textTheme.labelLarge?.copyWith(color: fgColor),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
