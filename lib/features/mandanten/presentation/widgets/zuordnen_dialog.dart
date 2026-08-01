import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnen_ergebnis.dart';
import 'package:flutter/material.dart';

/// Dialog: gefundenen Ordner einem bestehenden Mandanten zuordnen oder einen
/// neuen anlegen. Liefert ein [ZuordnenErgebnis] über Navigator.pop zurück.
class ZuordnenDialog extends StatelessWidget {
  final String ordnername;
  final List<Mandant> mandanten;

  const ZuordnenDialog({
    super.key,
    required this.ordnername,
    required this.mandanten,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ordner zuordnen'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ordner: „$ordnername"'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, const ZuordnenErgebnis.neu()),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Neuen Mandanten anlegen'),
            ),
            const SizedBox(height: 12),
            if (mandanten.isNotEmpty) ...[
              const Divider(),
              Text(
                'oder bestehendem Mandanten zuordnen:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in mandanten)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          m.anzeigename.isEmpty
                              ? '(ohne Namen)'
                              : m.anzeigename,
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          ZuordnenErgebnis.bestehend(m.id),
                        ),
                      ),
                  ],
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
}
