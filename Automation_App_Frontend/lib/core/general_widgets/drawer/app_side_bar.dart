import 'package:automation_app/core/general_widgets/drawer/sidebar_footer.dart';
import 'package:automation_app/core/general_widgets/drawer/side_bar_item.dart';
import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    required this.isExtended,
    required this.collapsedWidth,
    required this.expandedWidth,
    required this.animationDuration,
    required this.activeIndex,
    required this.onDestinationSelected,
    required this.onToggle,
    super.key,
  });

  final bool isExtended;
  final double collapsedWidth;
  final double expandedWidth;
  final Duration animationDuration;
  final int activeIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onToggle;

  static const _destinations = [
    (
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Übersicht',
    ),
    (
      icon: Icons.note_add_outlined,
      selectedIcon: Icons.note_add,
      label: 'Vorgang starten',
    ),
    (
      icon: Icons.mark_email_read_outlined,
      selectedIcon: Icons.mark_email_read,
      label: 'Postfach',
    ),
    (
      icon: Icons.document_scanner_outlined,
      selectedIcon: Icons.document_scanner,
      label: 'Word Automation',
    ),
    (
      icon: Icons.drive_file_rename_outline_outlined,
      selectedIcon: Icons.drive_file_rename_outline,
      label: 'Vorlagen Verwalten',
    ),
    (
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: 'Mandanten',
    ),
    (
      icon: Icons.table_chart_outlined,
      selectedIcon: Icons.table_chart,
      label: 'Register',
    ),
    (
      icon: Icons.folder_copy_outlined,
      selectedIcon: Icons.folder_copy,
      label: 'Vorgänge',
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Einstellungen',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeInOut,
      width: isExtended ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Markenkopf: nur der Toggle (immer sichtbar).
          SizedBox(
            height: 64,
            child: Row(
              children: [
                // Breite des Rahmens (1 px) abziehen, damit die Zeile in den
                // eingeklappten Innenraum passt und nicht überläuft.
                SizedBox(
                  width: collapsedWidth - 1,
                  child: Center(
                    child: IconButton(
                      onPressed: onToggle,
                      icon: const Icon(Icons.menu),
                      tooltip: isExtended ? 'Zuklappen' : 'Aufklappen',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Die Reiter nehmen den Platz zwischen Kopf und Fuß ein und scrollen,
          // wenn das Fenster zu niedrig ist. Ohne das lief die Spalte auf
          // kleinen Bildschirmen über (RenderFlex overflowed), und die unteren
          // Reiter waren nicht mehr erreichbar — der Fuß bleibt so immer sichtbar.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, dest) in _destinations.indexed)
                    SidebarItem(
                      icon: Icon(dest.icon),
                      selectedIcon: Icon(dest.selectedIcon),
                      label: dest.label,
                      isSelected: activeIndex == index,
                      isExtended: isExtended,
                      animationDuration: animationDuration,
                      collapsedWidth: collapsedWidth,
                      onTap: () => onDestinationSelected(index),
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          SidebarFooter(
            isExtended: isExtended,
            collapsedWidth: collapsedWidth,
            animationDuration: animationDuration,
          ),
        ],
      ),
    );
  }
}
