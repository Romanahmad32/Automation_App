import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandant_card.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_hinweis.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_leerer_zustand.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_sektion_kopf.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/nicht_zugeordnete_sektion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Mandantenliste. Der Zuordnungsstapel steht nur noch als Zähler darüber —
/// die Liste der Mandanten beginnt damit wieder oben, unabhängig davon, wie
/// viele Ordner offen sind.
class MandantenOverview extends StatelessWidget {
  final MandantenOverviewLoaded state;

  const MandantenOverview({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.mandanten.isEmpty && state.akten.isEmpty) {
      return const MandantenLeererZustand();
    }

    final gefiltert = state.gefilterteMandanten;
    final offen = state.offeneOrdnerAnzahl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        EntitySearchBar(
          initialQuery: state.query,
          hintText: 'Mandanten nach Name, Ort oder Ordner durchsuchen …',
          onChanged: (value) => context.read<MandantenOverviewBloc>().add(
            SearchMandantenEvent(value),
          ),
        ),
        if (offen > 0)
          NichtZugeordneteSektion(
            offen: offen,
            kandidaten: state.ordnerZaehler[OrdnerAnsicht.stapel] ?? 0,
          ),
        MandantenSektionKopf(
          anzahl: gefiltert.length,
          gesamt: state.mandanten.length,
          query: state.query,
        ),
        Expanded(child: _liste(gefiltert)),
      ],
    );
  }

  Widget _liste(List<Mandant> gefiltert) {
    if (state.mandanten.isEmpty) {
      return const MandantenHinweis(
        'Noch keine Mandanten gespeichert. Legen Sie über „Neuer Mandant" '
        'einen an oder ordnen Sie einen gefundenen Ordner zu.',
      );
    }
    if (gefiltert.isEmpty) {
      return MandantenHinweis('Kein Mandant passt zu „${state.query}".');
    }
    return ListView.builder(
      itemCount: gefiltert.length,
      itemBuilder: (_, i) => MandantCard(mandant: gefiltert[i], state: state),
    );
  }
}
