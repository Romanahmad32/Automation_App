import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';
import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_uebernahme.dart';
import 'package:flutter/material.dart';

/// Die erkannten {{Platzhalter}} einer Word-Datei als Chips, mit Zählzeile
/// und „Alle übernehmen" (#35 Teil 3). Drei Zustände je Chip:
///
/// - **offen**: Klick übernimmt den Platzhalter als Eingabefeld.
/// - **übernommen** (Name existiert schon als Feld): Häkchen, nicht klickbar.
/// - **app-eigen** ([AppEigenePlatzhalter]): füllt die App beim Erzeugen
///   selbst — nie klickbar, der Tooltip sagt warum.
class PlatzhalterChips extends StatelessWidget {
  final List<String> placeholders;

  /// Die aktuell eingetragenen Feldnamen (Werte der Formular-Controls).
  final Iterable<String?> vorhandeneNamen;

  final void Function(String placeholder) onPlaceholderSelected;

  /// Wird mit den tatsächlich zu übernehmenden Platzhaltern gerufen
  /// ([PlatzhalterUebernahme.uebernehmbare]). Null blendet den Knopf aus.
  final void Function(List<String> placeholders)? onAlleUebernehmen;

  const PlatzhalterChips({
    super.key,
    required this.placeholders,
    required this.onPlaceholderSelected,
    this.vorhandeneNamen = const [],
    this.onAlleUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uebernehmbar = PlatzhalterUebernahme.uebernehmbare(
      placeholders,
      vorhandeneNamen,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final placeholder in placeholders) _chip(placeholder),
          ],
        ),
        Row(
          spacing: 12,
          children: [
            Text(_zaehlzeile, style: theme.textTheme.bodySmall),
            if (onAlleUebernehmen != null)
              TextButton.icon(
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Alle übernehmen'),
                // Nichts mehr zu holen: Knopf sichtbar lassen, aber stumm —
                // so sieht der Anwalt, dass „alle" schon erledigt ist.
                onPressed: uebernehmbar.isEmpty
                    ? null
                    : () => onAlleUebernehmen!(uebernehmbar),
              ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String placeholder) {
    if (AppEigenePlatzhalter.istAppEigen(placeholder)) {
      return Tooltip(
        message:
            'Füllt die App beim Erzeugen selbst — '
            'kein Eingabefeld nötig.',
        child: Chip(
          avatar: const Icon(Icons.auto_awesome, size: 18),
          label: Text('{{$placeholder}}'),
        ),
      );
    }
    if (PlatzhalterUebernahme.istUebernommen(placeholder, vorhandeneNamen)) {
      return Tooltip(
        message: 'Bereits als Eingabefeld übernommen.',
        child: Chip(
          avatar: const Icon(Icons.check, size: 18),
          label: Text('{{$placeholder}}'),
        ),
      );
    }
    return ActionChip(
      avatar: const Icon(Icons.add, size: 18),
      label: Text('{{$placeholder}}'),
      tooltip: 'Als Eingabefeld übernehmen',
      onPressed: () => onPlaceholderSelected(placeholder),
    );
  }

  /// „14 von 18 übernommen" — gezählt wird nur, was übernehmbar ist:
  /// app-eigene Platzhalter sind nie Eingabefeld und zählen nicht mit.
  String get _zaehlzeile {
    final zaehlbar = [
      for (final placeholder in placeholders)
        if (!AppEigenePlatzhalter.istAppEigen(placeholder)) placeholder,
    ];
    final uebernommen = zaehlbar
        .where(
          (placeholder) => PlatzhalterUebernahme.istUebernommen(
            placeholder,
            vorhandeneNamen,
          ),
        )
        .length;
    return '$uebernommen von ${zaehlbar.length} übernommen';
  }
}
