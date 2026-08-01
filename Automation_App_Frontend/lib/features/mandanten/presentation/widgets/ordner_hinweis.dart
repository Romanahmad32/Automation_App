import 'package:flutter/material.dart';

/// Hinweis-Box auf dem Mandanten-Detailformular, die anzeigt, welcher Ordner
/// dem neu angelegten Mandanten zugeordnet wird (aus der manuellen Zuordnung
/// eines gefundenen Akten-Ordners).
class OrdnerHinweis extends StatelessWidget {
  final String ordnername;

  const OrdnerHinweis({super.key, required this.ordnername});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.link, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Der Ordner „$ordnername" wird diesem Mandanten zugeordnet. '
              'Der Namensvorschlag stammt aus dem Ordnernamen — bitte prüfen.',
              style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
