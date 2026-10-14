import 'dart:async';

import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:automation_app/core/general_widgets/drawer/sidebar_update_kachel.dart';
import 'package:material_ui/material_ui.dart';

/// Hinweis im Fuß der Seitenleiste, dass eine neuere Version bereitsteht —
/// und seit #196, wie weit die Aktualisierung ist:
///
/// - **1a** „Update verfügbar“ (auch nach einem Fehler: Die Version ist ja
///   weiter da),
/// - **1b** „Update wird geladen“ mit Ring und, ausgeklappt, Balken und
///   Prozent,
/// - **1c** „Update bereit · Neu starten“ als getönte Kachel
///   ([SidebarUpdateKachel]).
///
/// Erscheint nur, wenn es wirklich etwas Neueres gibt — eine gescheiterte
/// Prüfung bleibt hier stumm, sonst stünde bei jedem Netzausfall eine Meldung
/// da, die niemand auflösen kann.
///
/// Auch eingeklappt sichtbar: die Seitenleiste startet schmal, und ein
/// Hinweis, den man erst aufklappen muss, erreicht den Anwalt nie. Der Klick
/// öffnet den Dialog „App aktualisieren“ im passenden Zustand; der ganze Satz
/// steht im Tooltip.
class SidebarUpdateHinweis extends StatelessWidget {
  /// Öffnet nur den Dialog — in jedem der drei Zustände derselbe Schlüssel.
  static const Key schluessel = ValueKey('aktualisierung-hinweis');

  const SidebarUpdateHinweis({
    required this.ansicht,
    required this.isExtended,
    required this.collapsedWidth,
    required this.animationDuration,
    this.beiDruck,
    super.key,
  });

  final AktualisierungsAnsicht? ansicht;
  final bool isExtended;
  final double collapsedWidth;
  final Duration animationDuration;

  /// Ohne Angabe öffnet der Klick den Dialog „App aktualisieren“.
  final VoidCallback? beiDruck;

  @override
  Widget build(BuildContext context) {
    final stand = ansicht?.stand;
    if (stand == null || !stand.updateInSicht) return const SizedBox.shrink();

    final oeffnen =
        beiDruck ?? () => unawaited(AktualisierungsDialog.zeigen(context));
    if (stand.zustand == AktualisierungsZustand.bereit) {
      return SidebarUpdateKachel(
        key: schluessel,
        isExtended: isExtended,
        collapsedWidth: collapsedWidth,
        animationDuration: animationDuration,
        beiDruck: oeffnen,
      );
    }

    final laedt = stand.zustand == AktualisierungsZustand.laedt;
    final farbe = Theme.of(context).colorScheme.primary;
    return Tooltip(
      key: schluessel,
      message: laedt
          ? ladeText(stand)
          : 'Version ${stand.neueVersion} ist verfügbar',
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: oeffnen,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: laedt ? 56 : 48),
            child: Row(
              children: [
                SizedBox(
                  width: collapsedWidth - 1,
                  child: Center(
                    child: laedt
                        ? _ring(context, stand)
                        : Icon(Icons.system_update, color: farbe),
                  ),
                ),
                // Flexible statt eines unbeschränkten Row-Kindes, siehe
                // dieselbe Begründung in `side_bar_item.dart`: Ohne das
                // misst Align den Hinweis in seiner natürlichen Breite, und bei
                // größerer Schrift reißt das die Row über den rechten Rand.
                Flexible(
                  child: ClipRect(
                    child: AnimatedAlign(
                      duration: animationDuration,
                      curve: Curves.easeInOut,
                      alignment: Alignment.centerLeft,
                      widthFactor: isExtended ? 1 : 0,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: laedt
                            ? _ladeZeilen(context, stand)
                            : _beschriftung(context, 'Update verfügbar'),
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

  /// Tooltip in 1b: „Update wird geladen · 58 %“ — ohne bekannte Größe ohne
  /// Prozent.
  static String ladeText(AktualisierungsStand stand) {
    final prozent = stand.prozent;
    return prozent == null
        ? 'Update wird geladen'
        : 'Update wird geladen · $prozent %';
  }

  Widget _beschriftung(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  /// Der Ring zeigt den Stand auch eingeklappt; der Pfeil darin sagt „lädt“.
  Widget _ring(BuildContext context, AktualisierungsStand stand) {
    final schema = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(
              value: stand.anteil,
              strokeWidth: 3,
              backgroundColor: schema.surfaceContainerHighest,
            ),
          ),
          Icon(Icons.arrow_downward, size: 16, color: schema.primary),
        ],
      ),
    );
  }

  /// Zweizeilig: einzeilig passt „Update wird geladen · 58 %“ nicht in die
  /// ausgeklappten 236 px.
  Widget _ladeZeilen(BuildContext context, AktualisierungsStand stand) {
    final theme = Theme.of(context);
    final prozent = stand.prozent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _beschriftung(context, 'Update wird geladen'),
        const SizedBox(height: 3),
        // Während des Ein- und Ausklappens ist der Platz kurz fast null; die
        // Zeile mit Balken und Zahl entfällt dann, statt überzulaufen.
        LayoutBuilder(
          builder: (context, platz) => platz.maxWidth < 56
              ? const SizedBox.shrink()
              : Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: stand.anteil,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    if (prozent != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$prozent %',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
