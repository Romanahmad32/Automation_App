import 'package:automation_app/features/form_template_setup/domain/services/feld_vorkommen.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/auflistung_badge.dart';
import 'package:flutter/material.dart';

/// Das Symbol je Fall aus [FeldVorkommen] — reine Präsentation, das
/// Domain-Enum bleibt frei von Flutter und kennt keine `IconData`.
extension FeldVorkommenIcon on FeldVorkommen {
  IconData get icon => switch (this) {
    FeldVorkommen.beide => Icons.done_all,
    FeldVorkommen.nurHgn => Icons.description_outlined,
    FeldVorkommen.nurAuflistung => Icons.table_chart_outlined,
    FeldVorkommen.inKeinerDatei => Icons.link,
  };
}

/// Das Kennzeichen an einer Feldzeile, das zeigt, in welcher der beiden
/// Word-Dateien ein Platzhalter vorkommt — alle vier Fälle aus
/// [FeldVorkommen] (#104), auf ausdrücklichen Wunsch des Anwalts: Die beiden
/// Dateien sind gleichwertig, und er will an jeder Zeile sehen, welches Feld
/// welche Datei bedient, nicht nur, wenn eine von beiden es vermisst.
///
/// Drei Fälle sind reine Auskunft und bleiben deshalb ruhig — neutraler
/// Rahmen in `colorScheme.onSurfaceVariant`; `outline` als Schriftfarbe käme
/// auf der getönten Fläche nur auf 1,9:1 Kontrast. Nur [FeldVorkommen.inKeinerDatei] ist ein
/// Befund, der etwas kostet: Er sticht mit der Fehlerfarbe heraus und ist
/// zugleich der einzige Fall, der auf einen Klick reagiert — der Weg zur
/// Zuordnung (#36).
///
/// Baut auf [AuflistungBadge] auf (dieselbe Gestalt: `SoftTone`, Icon + Text,
/// einzeilig mit Ellipse) und legt nur Tooltip und Klickbarkeit darüber,
/// statt die Gestalt zu kopieren.
class FeldVorkommenPille extends StatelessWidget {
  final FeldVorkommen vorkommen;

  /// Ein Klick führt zur Zuordnung (#36) — wirkt nur bei
  /// [FeldVorkommen.inKeinerDatei]. Null lässt die Pille stumm — dort, wo es
  /// keine Platzhalterliste zum Wählen gibt.
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
    final istFehler = vorkommen == FeldVorkommen.inKeinerDatei;
    final zuordnen = istFehler ? onZuordnen : null;
    final farbe = istFehler
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Tooltip(
      message: zuordnen == null
          ? vorkommen.erklaerung
          : '${vorkommen.erklaerung} Anklicken, um einen Platzhalter '
                'zuzuordnen.',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maximalbreite),
        child: InkWell(
          onTap: zuordnen,
          borderRadius: BorderRadius.circular(8),
          child: AuflistungBadge(
            label: vorkommen.anzeige,
            accent: farbe,
            icon: vorkommen.icon,
          ),
        ),
      ),
    );
  }
}
