import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_suche_cubit/mandanten_suche_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnen_ergebnis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Dialog: gefundenen Ordner einem bestehenden Mandanten zuordnen oder einen
/// neuen anlegen. Liefert ein [ZuordnenErgebnis] über Navigator.pop zurück.
///
/// Die Suche fragt den Dienst und läuft damit über das **ganze** Register —
/// nicht über die Mandanten, die die Übersicht gerade geladen hat. Gezeigt
/// werden die ersten Treffer; steht die Zahl darüber höher, ist Weitersuchen
/// der Weg und nicht Scrollen.
class ZuordnenDialog extends StatefulWidget {
  final String ordnername;

  const ZuordnenDialog({super.key, required this.ordnername});

  @override
  State<ZuordnenDialog> createState() => _ZuordnenDialogState();
}

class _ZuordnenDialogState extends State<ZuordnenDialog> {
  @override
  void initState() {
    super.initState();
    context.read<MandantenSucheCubit>().laden();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            const Divider(),
            Text(
              'oder bestehendem Mandanten zuordnen:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            EntitySearchBar(
              initialQuery: '',
              hintText: 'Mandant suchen …',
              entprellung: MandantenSucheCubit.verzoegerung,
              onChanged: context.read<MandantenSucheCubit>().suche,
            ),
            const SizedBox(height: 8),
            BlocBuilder<MandantenSucheCubit, MandantenSucheState>(
              builder: (context, state) => _treffer(context, state),
            ),
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

  Widget _treffer(BuildContext context, MandantenSucheState state) {
    final theme = Theme.of(context);
    if (state.fehler != null) {
      return Text(
        state.fehler!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    if (state.treffer.isEmpty) {
      return Text(
        state.laedt
            ? 'Wird gesucht …'
            : state.query.isEmpty
            ? 'Noch kein Mandant gespeichert.'
            : 'Kein Mandant passt zu „${state.query}".',
        style: theme.textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.gekuerzt)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${state.treffer.length} von ${state.gefunden} Treffern — '
              'weiter eingrenzen, um den richtigen zu sehen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: state.treffer.length,
            itemBuilder: (_, i) => _kachel(context, state.treffer[i]),
          ),
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
