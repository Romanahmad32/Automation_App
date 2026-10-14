import 'package:automation_app/core/general_widgets/gerundeter_kasten.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:material_ui/material_ui.dart';

/// „Update bereit · Neu starten“ im Fuß der Seitenleiste (1c, #196) — eine
/// getönte Kachel mit Rand in der **Tertiärfarbe**: fällt auf, ist aber weder
/// rot noch bewegt. Nicht in der Primärfarbe, die trägt schon der gewählte
/// Reiter darüber.
///
/// Eingeklappt bleibt nur das Symbol in der Kachel; die Beschriftung klappt
/// wie die der Reiter mit (`ClipRect` über `AnimatedAlign`).
class SidebarUpdateKachel extends StatelessWidget {
  const SidebarUpdateKachel({
    required this.isExtended,
    required this.collapsedWidth,
    required this.animationDuration,
    required this.beiDruck,
    super.key,
  });

  final bool isExtended;
  final double collapsedWidth;
  final Duration animationDuration;
  final VoidCallback beiDruck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schema = theme.colorScheme;
    final ton = SoftTone.fromAccent(schema.tertiary, schema);
    return Tooltip(
      message: 'Update bereit – neu starten',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: GerundeterKasten(
          farbe: ton.background,
          randfarbe: ton.border,
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: beiDruck,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    // Wie die Reiter (`SidebarItem`): Innenraum minus Rand und
                    // Polster — passt so auch eingeklappt hinein.
                    SizedBox(
                      width: collapsedWidth - 18,
                      child: Icon(Icons.restart_alt, color: schema.tertiary),
                    ),
                    Flexible(
                      child: ClipRect(
                        child: AnimatedAlign(
                          duration: animationDuration,
                          curve: Curves.easeInOut,
                          alignment: Alignment.centerLeft,
                          widthFactor: isExtended ? 1 : 0,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _beschriftung(theme),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _beschriftung(ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Update bereit',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      Text(
        'Neu starten',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ],
  );
}
