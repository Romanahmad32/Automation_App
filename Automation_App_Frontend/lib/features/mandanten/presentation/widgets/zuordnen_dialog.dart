import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnen_ergebnis.dart';
import 'package:flutter/material.dart';

/// Dialog: gefundenen Ordner einem bestehenden Mandanten zuordnen oder einen
/// neuen anlegen. Liefert ein [ZuordnenErgebnis] über Navigator.pop zurück.
///
/// Die Mandantenliste hat eine eigene Suche und baut nur die sichtbaren
/// Einträge — sie wächst mit dem Register, und im Dialog ist ohnehin nur Platz
/// für eine Handvoll Zeilen.
class ZuordnenDialog extends StatefulWidget {
  final String ordnername;
  final List<Mandant> mandanten;

  const ZuordnenDialog({
    super.key,
    required this.ordnername,
    required this.mandanten,
  });

  @override
  State<ZuordnenDialog> createState() => _ZuordnenDialogState();
}

class _ZuordnenDialogState extends State<ZuordnenDialog> {
  String _query = '';

  List<Mandant> get _gefiltert {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.mandanten;
    return widget.mandanten
        .where((m) => m.anzeigename.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gefiltert = _gefiltert;
    return AlertDialog(
      title: const Text('Ordner zuordnen'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ordner: „${widget.ordnername}"'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, const ZuordnenErgebnis.neu()),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Neuen Mandanten anlegen'),
            ),
            const SizedBox(height: 12),
            if (widget.mandanten.isNotEmpty) ...[
              const Divider(),
              Text(
                'oder bestehendem Mandanten zuordnen:',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              EntitySearchBar(
                initialQuery: _query,
                hintText: 'Mandant suchen …',
                onChanged: (wert) => setState(() => _query = wert),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: gefiltert.isEmpty
                    ? Text(
                        'Kein Mandant passt zu „$_query".',
                        style: theme.textTheme.bodySmall,
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: gefiltert.length,
                        itemBuilder: (_, i) => _kachel(context, gefiltert[i]),
                      ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }

  Widget _kachel(BuildContext context, Mandant mandant) => ListTile(
    dense: true,
    leading: const Icon(Icons.person_outline),
    title: Text(
      mandant.anzeigename.isEmpty ? '(ohne Namen)' : mandant.anzeigename,
    ),
    onTap: () => Navigator.pop(context, ZuordnenErgebnis.bestehend(mandant.id)),
  );
}
