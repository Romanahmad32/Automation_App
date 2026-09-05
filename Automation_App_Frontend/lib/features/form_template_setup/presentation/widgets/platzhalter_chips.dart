import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';
import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_uebernahme.dart';
import 'package:flutter/material.dart';

/// Die erkannten {{Platzhalter}} einer Word-Datei als Chips. Drei Zustände je
/// Chip:
///
/// - **offen**: Platzhalter ohne Feld — Klick führt zur Zuordnung (#36).
/// - **übernommen** (Name existiert schon als Feld): Häkchen, nicht klickbar.
/// - **app-eigen** ([AppEigenePlatzhalter]): füllt die App beim Erzeugen
///   selbst — nie klickbar, der Tooltip sagt warum.
///
/// **Gezählt wird hier nicht mehr** (#104): Unter den Chips standen bis Stufe 2
/// eine rote Warnzeile („3 Platzhalter ohne Feld …") und ein „14 von 18
/// übernommen" — je Word-Datei einmal. Bei zwei verknüpften Dateien las der
/// Anwalt vier Zahlen, von denen keine für die Vorlage galt: Derselbe
/// Platzhalter in beiden Dateien zählte doppelt. Beides sagt jetzt
/// `VorlagenStandKarte` in einer Rechnung über beide Dateien, und „Alle
/// übernehmen" steht dort daneben. Der Chip bleibt, was er immer war — der
/// Weg zu **diesem** Platzhalter.
class PlatzhalterChips extends StatelessWidget {
  final List<String> placeholders;

  /// Die aktuell eingetragenen Feldnamen (Werte der Formular-Controls).
  final Iterable<String?> vorhandeneNamen;

  final void Function(String placeholder) onPlaceholderSelected;

  const PlatzhalterChips({
    super.key,
    required this.placeholders,
    required this.onPlaceholderSelected,
    this.vorhandeneNamen = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final placeholder in placeholders) _chip(placeholder)],
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
      tooltip:
          'Platzhalter ohne Feld — bleibt beim Erzeugen roh im Dokument '
          'stehen. Anklicken, um ihn zuzuordnen.',
      onPressed: () => onPlaceholderSelected(placeholder),
    );
  }
}
