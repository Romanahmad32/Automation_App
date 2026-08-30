import 'package:automation_app/features/form_template_setup/domain/services/app_eigene_platzhalter.dart';
import 'package:flutter/material.dart';

/// Die erkannten {{Platzhalter}} einer Word-Datei als Chips. Ein Klick
/// übernimmt den Platzhalter als Eingabefeld — außer bei app-eigenen
/// ([AppEigenePlatzhalter]): Die füllt die App beim Erzeugen selbst, ihr Chip
/// ist deshalb nicht klickbar und sagt das im Tooltip, statt ein Feld zu
/// erzeugen, das sich nie füllen lässt (#35).
class PlatzhalterChips extends StatelessWidget {
  final List<String> placeholders;
  final void Function(String placeholder) onPlaceholderSelected;

  const PlatzhalterChips({
    super.key,
    required this.placeholders,
    required this.onPlaceholderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final placeholder in placeholders)
          if (AppEigenePlatzhalter.istAppEigen(placeholder))
            Tooltip(
              message:
                  'Füllt die App beim Erzeugen selbst — '
                  'kein Eingabefeld nötig.',
              child: Chip(
                avatar: const Icon(Icons.auto_awesome, size: 18),
                label: Text('{{$placeholder}}'),
              ),
            )
          else
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text('{{$placeholder}}'),
              tooltip: 'Als Eingabefeld übernehmen',
              onPressed: () => onPlaceholderSelected(placeholder),
            ),
      ],
    );
  }
}
