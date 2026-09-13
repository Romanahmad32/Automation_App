import 'package:automation_app/core/general_widgets/gerundeter_kasten.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Einzeilige, anklickbare Hinweiszeile oben in der Karte „Offene Vorgänge":
/// wie viele offene Vorgänge noch keine gedruckte Vollmacht haben (§4.11).
/// Ein Klick springt in die Vorgangsverwaltung (Tab 7), wo die Vollmacht
/// gedruckt bzw. der Vermerk von Hand gesetzt wird — diese Zeile zeigt nur an.
class DashboardVollmachtHinweis extends StatelessWidget {
  final int anzahl;

  const DashboardVollmachtHinweis({super.key, required this.anzahl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = SoftTone.fromAccent(
      theme.colorScheme.tertiary,
      theme.colorScheme,
    );
    final text = anzahl == 1
        ? '1 offener Vorgang ohne gedruckte Vollmacht'
        : '$anzahl offene Vorgänge ohne gedruckte Vollmacht';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GerundeterKasten(
        farbe: tone.background,
        child: InkWell(
          onTap: () =>
              AutoTabsRouter.of(context).setActiveIndex(AppTabIndex.vorgaenge),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.draw_outlined, size: 18, color: tone.foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tone.foreground,
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
