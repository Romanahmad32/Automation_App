import 'package:automation_app/features/email_versand/domain/entities/versand_pruefung.dart';
import 'package:flutter/material.dart';

/// Die schmale Statuszeile über den Schaltflächen: Was zum Senden noch fehlt —
/// **vor** dem Klick (§4.7, ergänzt am 06.09.2026).
///
/// **Der Mangel, den das behebt:** „Nicht versandbereit" erschien erst, nachdem
/// „Senden" gedrückt war. Der Knopf ist bewusst anfassbar (§1.3: ein
/// abgeblendeter Knopf ist eine Behauptung ohne Begründung) — nur stand die
/// Begründung eben nirgends, solange niemand drückte.
///
/// Sie steht **immer** da, auch im grünen Fall. Eine Zeile, die nur bei einem
/// Mangel erscheint, verschiebt die Knöpfe darunter genau in dem Augenblick, in
/// dem jemand auf sie zielt.
///
/// Genannt wird nur der **erste** offene Punkt: Wer drei Sätze gleichzeitig
/// vorgesetzt bekommt, liest keinen davon; die übrigen stehen ohnehin an ihrem
/// Feld.
class VersandBereitschaftZeile extends StatelessWidget {
  final VersandPruefung pruefung;

  const VersandBereitschaftZeile({super.key, required this.pruefung});

  /// Der Satz im grünen Fall. Öffentlich, weil ein Test darauf zeigt.
  static const String bereitText = 'Versandbereit — alles Nötige steht.';

  /// Wie viele Punkte **ausser** dem genannten noch offen sind — mit gebeugtem
  /// Zahlwort. Öffentlich, weil ein Test darauf zeigt: „und 1 weitere" wäre ein
  /// Schnitzer in einer App, die deutsche Briefe schreibt.
  static String? weitereText(int punkte) => switch (punkte) {
    < 2 => null,
    2 => 'und ein weiterer',
    _ => 'und ${punkte - 1} weitere',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offen = pruefung.erster;
    // Der Ton der übrigen Hinweise im Dialog, kein Alarmrot: Ein Entwurf, an
    // dem noch etwas fehlt, ist der Regelfall kurz vor dem Senden.
    final ton = offen == null
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.tertiary;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Icon(
            offen == null ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: ton,
          ),
          Expanded(
            child: Text(
              offen ?? bereitText,
              style: theme.textTheme.bodySmall?.copyWith(color: ton),
            ),
          ),
          if (weitereText(pruefung.punkte.length) case final weitere?)
            Text(
              weitere,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
