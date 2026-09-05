import 'package:automation_app/features/form_template_setup/domain/services/feld_vorkommen.dart';
import 'package:flutter/material.dart';

/// Das kleine Kennzeichen „in keiner Datei" neben dem Feldnamen — der
/// sichtbare Teil von [FeldVorkommen], ohne jede eigene Logik.
///
/// Es steht **in** der Bezeichnungszelle und nicht mehr unter der Zeile: Die
/// Warnung gehört an den Namen, der falsch ist, und eine Zeile, die je nach
/// Befund höher wird, lässt die Tabelle springen.
///
/// Es begrenzt sich selbst auf [maximalbreite] und lässt seinen Text notfalls
/// auslaufen. Neben ihm steht ein Eingabefeld, das mit `Expanded` den Rest
/// nimmt — ohne die Grenze schöbe die Pille bei angehobener Schrift
/// (Issue #57) das Feld aus der Spalte.
class FeldVorkommenPille extends StatelessWidget {
  final FeldVorkommen vorkommen;

  /// Ein Klick führt zur Zuordnung (#36). Null lässt die Pille stumm — dort,
  /// wo es keine Platzhalterliste zum Wählen gibt.
  final VoidCallback? onZuordnen;

  const FeldVorkommenPille({
    super.key,
    required this.vorkommen,
    this.onZuordnen,
  });

  /// So breit darf die Pille höchstens werden.
  static const double maximalbreite = 130;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farbe = theme.colorScheme.error;
    final zuordnen = onZuordnen;

    return Tooltip(
      message: zuordnen == null
          ? vorkommen.erklaerung
          : '${vorkommen.erklaerung} Anklicken, um einen Platzhalter '
                'zuzuordnen.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maximalbreite),
        child: InkWell(
          onTap: zuordnen,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              border: Border.all(color: farbe),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Flexible(
                  child: Text(
                    vorkommen.anzeige,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: farbe),
                  ),
                ),
                if (zuordnen != null) Icon(Icons.link, size: 12, color: farbe),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
