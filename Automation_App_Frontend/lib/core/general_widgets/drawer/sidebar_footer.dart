import 'package:automation_app/core/aktualisierung/aktualisierung_builder.dart';
import 'package:automation_app/core/general_widgets/drawer/sidebar_theme_toggle.dart';
import 'package:automation_app/core/general_widgets/drawer/sidebar_update_hinweis.dart';
import 'package:automation_app/core/general_widgets/version_badge.dart';
import 'package:flutter/material.dart';

/// Fuß der Seitenleiste: Update-Hinweis, Helligkeitsschalter und die laufende
/// Version.
///
/// Die Version klappt mit der Leiste ein und aus — nach demselben Muster wie
/// die Beschriftungen der Einträge (`ClipRect` über `AnimatedAlign`), damit
/// während der Animation nichts überläuft.
class SidebarFooter extends StatelessWidget {
  const SidebarFooter({
    required this.isExtended,
    required this.collapsedWidth,
    required this.animationDuration,
    super.key,
  });

  final bool isExtended;
  final double collapsedWidth;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return AktualisierungBuilder(
      builder: (context, stand) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SidebarUpdateHinweis(
            stand: stand,
            isExtended: isExtended,
            collapsedWidth: collapsedWidth,
            animationDuration: animationDuration,
          ),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                // Breite des Rahmens (1 px) abziehen, damit die Zeile in den
                // eingeklappten Innenraum passt und nicht überläuft.
                SizedBox(
                  width: collapsedWidth - 1,
                  child: const Center(child: SidebarThemeToggle()),
                ),
                ClipRect(
                  child: AnimatedAlign(
                    duration: animationDuration,
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerLeft,
                    widthFactor: isExtended ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: VersionBadge(stand: stand),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
