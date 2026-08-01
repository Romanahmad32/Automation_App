import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/akte_block.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandant_info_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Aufklappbare Karte eines Mandanten: Stammdaten, Kennzahlen (Akten/Fälle),
/// Aktionen (bearbeiten/löschen) und die zugeordneten Akten.
class MandantCard extends StatelessWidget {
  final Mandant mandant;
  final MandantenOverviewLoaded state;

  const MandantCard({super.key, required this.mandant, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final akten = state.aktenFuer(mandant);
    final fallAnzahl = akten.fold<int>(0, (sum, a) => sum + a.faelle.length);
    final adresse = [
      mandant.strasseHausnummer,
      [mandant.postleitzahl, mandant.ort].where((e) => e.isNotEmpty).join(' '),
    ].where((e) => e.trim().isNotEmpty).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Text(
            _initialen(mandant),
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ),
        title: Text(
          _titel(mandant),
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          adresse.isEmpty ? 'Keine Adresse hinterlegt' : adresse,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Row(
            children: [
              MandantInfoChip(
                icon: Icons.folder_outlined,
                label:
                    '${akten.length} ${akten.length == 1 ? 'Akte' : 'Akten'}',
              ),
              const SizedBox(width: 8),
              MandantInfoChip(
                icon: Icons.description_outlined,
                label: '$fallAnzahl ${fallAnzahl == 1 ? 'Fall' : 'Fälle'}',
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _bearbeiten(context),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Mandant bearbeiten',
              ),
              IconButton(
                onPressed: () => _loeschen(context),
                icon: const Icon(Icons.delete_outline),
                color: scheme.error,
                tooltip: 'Mandant löschen',
              ),
            ],
          ),
          if (mandant.kennzeichen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in mandant.kennzeichen)
                      MandantInfoChip(
                        icon: Icons.directions_car_outlined,
                        label: k,
                      ),
                  ],
                ),
              ),
            ),
          if (akten.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Noch keine Akte zugeordnet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
            )
          else
            for (final akte in akten) AkteBlock(akte: akte),
        ],
      ),
    );
  }

  /// Titel „Anrede Vorname Nachname"; ohne Namen ein Platzhalter.
  String _titel(Mandant m) {
    if (m.anzeigename.isEmpty) return '(ohne Namen)';
    final kurz = m.anrede.kurzform;
    return kurz.isEmpty ? m.anzeigename : '$kurz ${m.anzeigename}';
  }

  String _initialen(Mandant m) {
    final v = m.vorname.isNotEmpty ? m.vorname[0] : '';
    final n = m.nachname.isNotEmpty ? m.nachname[0] : '';
    final s = '$v$n'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  Future<void> _bearbeiten(BuildContext context) async {
    final bloc = context.read<MandantenOverviewBloc>();
    final didChange = await context.router.push<bool>(
      MandantDetailsRoute(mandant: mandant),
    );
    if (didChange == true) {
      bloc.add(LoadMandantenUebersichtEvent());
    }
  }

  void _loeschen(BuildContext context) {
    final bloc = context.read<MandantenOverviewBloc>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_rounded,
          size: 40,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Löschen bestätigen'),
        content: Text(
          'Soll der Mandant „${mandant.anzeigename}" aus der App entfernt '
          'werden? Die Akten-Ordner im Dateisystem bleiben unberührt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              bloc.add(DeleteMandantEvent(mandant.id));
              Navigator.pop(dialogContext);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}
