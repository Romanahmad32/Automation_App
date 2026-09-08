import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:flutter/material.dart';

/// Erklärt, was die drei Knöpfe im Kopf dieser Seite miteinander zu tun haben.
///
/// Ohne diese Erklärung sehen die drei Knöpfe wie gleichartige Import-Aktionen
/// aus. Anders als eine ganz verschwindende Erklärung bleibt die Kopfzeile
/// **immer** da — nur zu- statt aufgeklappt, sobald schon ein Arbeitspaket
/// geholt wurde. Ein einmal geholtes Testpaket (oder ein Anwalt, der es
/// vergisst) darf die Erklärung nicht endgültig unsichtbar machen; das kostet
/// nur einen Klick zum erneuten Aufklappen.
class ZuordnungAblaufHinweis extends StatelessWidget {
  /// Ob das Band beim ersten Anzeigen offen steht — vorgesehen für „noch kein
  /// Arbeitspaket geholt".
  final bool anfangsOffen;

  const ZuordnungAblaufHinweis({super.key, required this.anfangsOffen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    final tone = SoftTone.fromAccent(farben.primary, farben);

    return Container(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.border),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: anfangsOffen,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: tone.foreground,
          collapsedIconColor: tone.foreground,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(Icons.route_outlined, color: tone.foreground),
          title: Text(
            'So werden viele Ordner auf einmal zugeordnet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tone.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '1. Arbeitspaket holen gibt eine Portion offener Ordner '
                'heraus — die Anleitung dafür liegt danach in der '
                'Zwischenablage.\n'
                '2. Außerhalb dieser App wird darin je Ordner der Mandant '
                'eingetragen.\n'
                '3. Aus Datei übernehmen liest das Ergebnis hier wieder ein, '
                'zur Prüfung vor jeder Übernahme.\n\n'
                'Für Ordner, die sich ohne Nachlesen sicher zuordnen lassen, '
                'reicht Sichere Treffer übernehmen — ganz ohne Umweg über '
                'eine Datei.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tone.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
