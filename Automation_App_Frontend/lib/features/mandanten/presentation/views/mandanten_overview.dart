import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandant_card.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_hinweis.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_leerer_zustand.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_sektion_kopf.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/nicht_zugeordnete_sektion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MandantenOverview extends StatelessWidget {
  final MandantenOverviewLoaded state;

  const MandantenOverview({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.mandanten.isEmpty && state.akten.isEmpty) {
      return const MandantenLeererZustand();
    }

    final gefiltert = state.gefilterteMandanten;
    final nichtZugeordnet = state.nichtZugeordneteAkten;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntitySearchBar(
          initialQuery: state.query,
          hintText: 'Mandanten nach Name, Ort oder Ordner durchsuchen …',
          onChanged: (value) => context.read<MandantenOverviewBloc>().add(
            SearchMandantenEvent(value),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              if (nichtZugeordnet.isNotEmpty) ...[
                NichtZugeordneteSektion(akten: nichtZugeordnet, state: state),
                const SizedBox(height: 20),
              ],
              MandantenSektionKopf(
                anzahl: gefiltert.length,
                gesamt: state.mandanten.length,
                query: state.query,
              ),
              const SizedBox(height: 8),
              if (state.mandanten.isEmpty)
                const MandantenHinweis(
                  'Noch keine Mandanten gespeichert. Legen Sie über „Neuer '
                  'Mandant" einen an oder ordnen Sie einen gefundenen Ordner zu.',
                )
              else if (gefiltert.isEmpty)
                MandantenHinweis('Kein Mandant passt zu „${state.query}".')
              else
                for (final mandant in gefiltert)
                  MandantCard(mandant: mandant, state: state),
            ],
          ),
        ),
      ],
    );
  }
}
