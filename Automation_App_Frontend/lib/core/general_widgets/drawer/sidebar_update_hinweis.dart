import 'package:automation_app/core/aktualisierung/aktualisierungs_ergebnis.dart';
import 'package:automation_app/core/general_widgets/ueber_anwendung_dialog.dart';
import 'package:flutter/material.dart';

/// Hinweis in der Seitenleiste, dass eine neuere Version bereitsteht.
///
/// Erscheint nur, wenn es wirklich etwas Neueres gibt — eine gescheiterte
/// Prüfung bleibt hier stumm, sonst stünde bei jedem Netzausfall eine Meldung
/// da, die niemand auflösen kann.
///
/// Auch eingeklappt sichtbar: die Seitenleiste startet schmal, und ein Hinweis,
/// den man erst aufklappen muss, erreicht den Anwalt nie. Der Klick öffnet den
/// Dialog statt direkt den Browser — dort steht, was ihn erwartet.
class SidebarUpdateHinweis extends StatelessWidget {
  const SidebarUpdateHinweis({
    required this.stand,
    required this.isExtended,
    required this.collapsedWidth,
    required this.animationDuration,
    super.key,
  });

  final AktualisierungsErgebnis? stand;
  final bool isExtended;
  final double collapsedWidth;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final neu = stand?.neueVersion;
    if (neu == null) return const SizedBox.shrink();

    final farbe = Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: 'Version ${neu.nummer} ist verfügbar',
      child: InkWell(
        onTap: () => UeberAnwendungDialog.zeigen(context, stand),
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(
                width: collapsedWidth - 1,
                child: Center(child: Icon(Icons.system_update, color: farbe)),
              ),
              ClipRect(
                child: AnimatedAlign(
                  duration: animationDuration,
                  curve: Curves.easeInOut,
                  alignment: Alignment.centerLeft,
                  widthFactor: isExtended ? 1 : 0,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      'Update verfügbar',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: farbe),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
