import 'package:flutter/material.dart';

/// Der Abschluss einer langen Liste: entweder „es kommt noch etwas" oder
/// „das war alles". Benutzt von der Mandantenliste und vom Zuordnungsstapel —
/// die beiden sagen mit [meldung] verschiedene Dinge, weil bei der einen ein
/// Abruf nachlädt und die andere nur mehr von einem vorliegenden Bestand
/// zeigt.
///
/// Er steht als letzte Zeile in der Liste selbst und nicht darunter, damit er
/// mitscrollt — und er ist der Grund, warum der Anwalt nach 50 Zeilen nicht
/// glaubt, sein Register habe nur 50 Einträge.
class MandantenListenFuss extends StatelessWidget {
  /// Wie viele Mandanten gerade geladen sind.
  final int geladen;

  /// Wie viele es insgesamt zu holen gibt (mit der aktuellen Suche).
  final int gesamt;

  /// Ob gerade nachgeladen wird.
  final bool laedt;

  /// Der Satz über den Zahlen. Ohne Angabe der Wortlaut der Mandantenliste,
  /// die tatsächlich beim Dienst nachlädt.
  final String? meldung;

  const MandantenListenFuss({
    super.key,
    required this.geladen,
    required this.gesamt,
    required this.laedt,
    this.meldung,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (geladen >= gesamt) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        spacing: 8,
        children: [
          if (laedt) const LinearProgressIndicator(minHeight: 2),
          Text(
            meldung ??
                '$geladen von $gesamt geladen — weiterscrollen lädt nach.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
