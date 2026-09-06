import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:flutter/material.dart';

/// „Stand dieser Vorlage" — was der Vorlage noch fehlt, an **einer** Stelle
/// (#104, §5.3).
///
/// Vorher stand dieselbe Auskunft zweimal, je Word-Datei getrennt, unter den
/// Platzhalter-Chips: eine rote Warnzeile und ein „14 von 18 übernommen". Wer
/// beide Dateien verknüpft hatte, las vier Zahlen und bekam trotzdem keine
/// Aussage über die Vorlage als Ganzes — ein Platzhalter in beiden Dateien
/// zählte doppelt. [VorlagenStand] rechnet einmal, und diese Karte zeigt genau
/// diese eine Rechnung.
///
/// Der Ton kommt wie bei `AuflistungBadge` über [SoftTone] aus einer
/// Akzentfarbe: `primaryContainer`, solange die Vorlage vollständig ist,
/// `error`, solange ihr etwas fehlt. Das ist der einzige Farbwechsel der
/// Karte — die einzelnen Zeilen tragen ihre eigene Rolle.
///
/// **Die beiden Word-Dateien sind gleichwertig.** Ein leerer Slot ist kein
/// Mangel und bekommt keinen Warnton; die Dateizeile sagt neutral, was
/// verknüpft ist. Unvollständig ist eine Vorlage nur ohne **jede** Datei oder
/// mit einem Platzhalter ohne Feld.
class VorlagenStandKarte extends StatelessWidget {
  final VorlagenStand stand;

  /// Wird mit [VorlagenStand.platzhalterOhneFeld] gerufen — derselbe Weg wie
  /// früher der Knopf unter den Chips. Null blendet ihn aus; ohne offene
  /// Platzhalter erscheint er ohnehin nicht, statt stumm dazustehen.
  final void Function(List<String> platzhalter)? onAlleUebernehmen;

  const VorlagenStandKarte({
    super.key,
    required this.stand,
    this.onAlleUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    final ton = SoftTone.fromAccent(
      stand.istVollstaendig ? farben.primaryContainer : farben.error,
      farben,
    );

    return Card(
      color: ton.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              spacing: 10,
              children: [
                Icon(
                  stand.istVollstaendig
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: ton.foreground,
                ),
                Expanded(
                  child: Text(
                    'Stand dieser Vorlage',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ton.foreground,
                    ),
                  ),
                ),
              ],
            ),
            if (stand.istVollstaendig)
              _zeile(
                theme,
                Icons.check,
                'Vollständig — alle Platzhalter haben ein Feld',
                ton.foreground,
              ),
            if (stand.mangelText case final text?)
              _zeile(theme, Icons.report_gmailerrorred, text, farben.error),
            if (stand.warnungText case final text?)
              _zeile(theme, Icons.warning_amber, text, farben.tertiary),
            if (stand.unbekanntText case final text?)
              _zeile(
                theme,
                Icons.hourglass_empty,
                text,
                farben.onSurfaceVariant,
              ),
            if (_dateiText case final text?)
              _zeile(
                theme,
                Icons.description_outlined,
                text,
                farben.onSurfaceVariant,
              ),
            if (stand.platzhalterOhneFeld.isNotEmpty &&
                onAlleUebernehmen != null)
              TextButton.icon(
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Alle übernehmen'),
                onPressed: () =>
                    onAlleUebernehmen!(stand.platzhalterOhneFeld.toList()),
              ),
          ],
        ),
      ),
    );
  }

  /// Welche Dateien verknüpft sind — **neutral**, ohne Warnton: Eine Vorlage
  /// darf mit nur einer der beiden auskommen. Ohne jede Datei schweigt die
  /// Zeile, das sagt schon der Mangel darüber.
  String? get _dateiText {
    if (stand.hatDateiOhne && stand.hatDateiMit) {
      return 'Verknüpft: ohne und mit Schadensaufstellung';
    }
    if (stand.hatDateiOhne) return 'Verknüpft: ohne Schadensaufstellung';
    if (stand.hatDateiMit) return 'Verknüpft: mit Schadensaufstellung';
    return null;
  }

  Widget _zeile(ThemeData theme, IconData symbol, String text, Color farbe) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Icon(symbol, size: 18, color: farbe),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: farbe),
          ),
        ),
      ],
    );
  }
}
