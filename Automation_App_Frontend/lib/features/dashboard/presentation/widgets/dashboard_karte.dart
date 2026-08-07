import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Gemeinsamer Rahmen der drei Startseiten-Bereiche: Überschrift mit Icon,
/// optionaler Umfangshinweis („5 von 12") und der Absprung in den Tab, der den
/// Bereich vollständig zeigt. Der Inhalt selbst kommt als [child].
class DashboardKarte extends StatelessWidget {
  final String titel;
  final IconData icon;

  /// Kurzer Hinweis auf den Umfang, z. B. „5 von 12". Null blendet ihn aus.
  final String? umfang;

  /// Beschriftung und Ziel-Tab des Absprungs (Sidebar-Index aus `AppTabIndex`).
  final String aktionLabel;
  final int zielTab;

  final Widget child;

  const DashboardKarte({
    super.key,
    required this.titel,
    required this.icon,
    required this.aktionLabel,
    required this.zielTab,
    required this.child,
    this.umfang,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    titel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (umfang case final text?) ...[
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      AutoTabsRouter.of(context).setActiveIndex(zielTab),
                  child: Text(aktionLabel),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}
