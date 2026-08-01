import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/ordnername_vorschlag.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnen_dialog.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnen_ergebnis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sektion mit gefundenen Ordnern, die noch keinem Mandanten zugeordnet sind.
/// Pro Ordner kann ein Zuordnen-Dialog geöffnet werden, der entweder einen
/// neuen Mandanten anlegt oder den Ordner einem bestehenden zuordnet.
class NichtZugeordneteSektion extends StatelessWidget {
  final List<Akte> akten;
  final MandantenOverviewLoaded state;

  const NichtZugeordneteSektion({
    super.key,
    required this.akten,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rule_folder_outlined,
                size: 20,
                color: scheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Nicht zugeordnete Ordner (${akten.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Im Stammordner gefundene Ordner ohne Mandanten-Zuordnung. Ordnen '
            'Sie jeden einem bestehenden oder neuen Mandanten zu.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
          const SizedBox(height: 8),
          for (final akte in akten)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.folder_off_outlined, color: scheme.outline),
              title: Text(akte.ordnername),
              subtitle: Text(
                '${akte.faelle.length} ${akte.faelle.length == 1 ? 'Fall' : 'Fälle'}',
              ),
              trailing: FilledButton.tonalIcon(
                onPressed: () => _zuordnen(context, akte),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Zuordnen'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _zuordnen(BuildContext context, Akte akte) async {
    final bloc = context.read<MandantenOverviewBloc>();
    final router = context.router;
    final auswahl = await showDialog<ZuordnenErgebnis>(
      context: context,
      builder: (_) => ZuordnenDialog(
        ordnername: akte.ordnername,
        mandanten: state.mandanten,
      ),
    );
    if (auswahl == null) return;

    if (auswahl.neuerMandant) {
      final vorschlag = nameVorschlagAusOrdner(akte.ordnername);
      final didChange = await router.push<bool>(
        MandantDetailsRoute(
          vorbelegterOrdner: akte.ordnername,
          vorbelegterVorname: vorschlag.vorname,
          vorbelegterNachname: vorschlag.nachname,
        ),
      );
      if (didChange == true) bloc.add(LoadMandantenUebersichtEvent());
    } else {
      bloc.add(
        VerknuepfeOrdnerEvent(
          mandantId: auswahl.mandantId!,
          ordnername: akte.ordnername,
        ),
      );
    }
  }
}
