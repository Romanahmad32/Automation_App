import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/dev_simulation/presentation/widgets/demo_vorgang_button.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_bearbeiten_dialog.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_verwaltung_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Verwaltung aller Vorgänge (jeder Status): auflisten, bearbeiten und löschen.
/// Anders als das Sachgebiete-Register (nur abgeschlossene Vorgänge, read-only)
/// ist dies die zentrale Pflege-Ansicht für die gebündelten Vorgangsdaten.
@RoutePage()
class VorgaengeVerwaltenPage extends StatelessWidget {
  const VorgaengeVerwaltenPage({super.key});

  /// Alle Vorgänge, neueste Anfrage zuerst.
  List<Vorgang> _sortiert(List<Vorgang> vorgaenge) {
    final liste = [...vorgaenge];
    liste.sort((a, b) => b.angefragtAm.compareTo(a.angefragtAm));
    return liste;
  }

  Future<void> _bearbeiten(BuildContext context, Vorgang vorgang) async {
    final cubit = getIt<VorgangCubit>();
    await showDialog<void>(
      context: context,
      builder: (_) => VorgangBearbeitenDialog(
        vorgang: vorgang,
        onSave: cubit.aktualisiere,
        onReferenzAendern: cubit.aendereReferenz,
      ),
    );
  }

  Future<void> _loeschen(BuildContext context, Vorgang vorgang) async {
    final cubit = getIt<VorgangCubit>();
    final bestaetigt = await bestaetigen(
      context,
      titel: 'Vorgang löschen?',
      text:
          'Der Vorgang „${vorgang.referenz}" wird endgültig gelöscht. '
          'Dies kann nicht rückgängig gemacht werden.',
      bestaetigung: 'Löschen',
      destruktiv: true,
    );
    if (bestaetigt) {
      await cubit.loesche(vorgang.referenz);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const SeitenAppBar(
        titel: 'Vorgänge verwalten',
        icon: Icons.folder_copy_outlined,
        untertitel: 'Alle Vorgänge mit ihrem Stand im Ablauf',
        // Nur im Debug-Build sichtbar (Entwickler-Simulation).
        aktionen: [DemoVorgangButton()],
      ),
      body: BlocBuilder<VorgangCubit, List<Vorgang>>(
        bloc: getIt<VorgangCubit>(),
        builder: (context, vorgaenge) {
          if (vorgaenge.isEmpty) {
            return const VorgaengeLeerHinweis();
          }
          final liste = _sortiert(vorgaenge);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Text(
                  '${liste.length} Vorgänge. Daten bearbeiten oder einzelne '
                  'Vorgänge löschen.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: liste.length,
                  itemBuilder: (context, index) {
                    final vorgang = liste[index];
                    return VorgangVerwaltungTile(
                      vorgang: vorgang,
                      onEdit: () => _bearbeiten(context, vorgang),
                      onDelete: () => _loeschen(context, vorgang),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Hinweis, solange noch keine Vorgänge angelegt wurden.
class VorgaengeLeerHinweis extends StatelessWidget {
  const VorgaengeLeerHinweis({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Vorgänge. Sobald eine Zentralruf-Anfrage gestartet '
              'oder eine Antwort übernommen wird, erscheint der Vorgang hier.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
