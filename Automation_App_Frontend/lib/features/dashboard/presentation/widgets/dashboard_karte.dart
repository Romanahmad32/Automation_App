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
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                // Titel und Umfang teilen sich den gesamten freien Platz, damit
                // der Absprung rechts bündig an der Kartenkante klebt und beim
                // Verbreitern/Verschmälern der Karte mitwandert.
                Expanded(
                  child: Row(
                    children: [
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
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Bewusst als gefüllte Tonal-Schaltfläche mit großzügiger
                // Trefferfläche (44 px hoch): der Absprung ist auf der
                // Startseite die eigentliche Handlung jeder Karte.
                FilledButton.tonalIcon(
                  onPressed: () =>
                      AutoTabsRouter.of(context).setActiveIndex(zielTab),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(aktionLabel),
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
