import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_filter.dart';
import 'package:flutter/material.dart';

/// Die Filterreihe über der Posteingangsliste — vier `ChoiceChip`s, genau
/// einer gilt (`auswahl_themes.dart`, Issue #134). Das Häkchen der Auswahl
/// kommt aus dem App-Theme und wird hier nicht abgeschaltet.
class PosteingangFilterLeiste extends StatelessWidget {
  const PosteingangFilterLeiste({
    super.key,
    required this.filter,
    required this.zentralrufAnzahl,
    required this.onChanged,
  });

  final PosteingangFilter filter;
  final int zentralrufAnzahl;
  final ValueChanged<PosteingangFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _chip(PosteingangFilter.alle, 'Alle'),
          _chip(PosteingangFilter.zentralruf, 'Zentralruf ($zentralrufAnzahl)'),
          _chip(PosteingangFilter.mitVorgang, 'Mit Vorgang'),
          _chip(PosteingangFilter.ohneBezug, 'Ohne Bezug'),
        ],
      ),
    );
  }

  ChoiceChip _chip(PosteingangFilter wert, String text) => ChoiceChip(
    label: Text(text),
    selected: filter == wert,
    onSelected: (_) => onChanged(wert),
  );
}
