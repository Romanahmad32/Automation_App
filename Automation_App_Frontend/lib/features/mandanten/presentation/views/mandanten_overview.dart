import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandant_card.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_hinweis.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_leerer_zustand.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_listen_fuss.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_sektion_kopf.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/nicht_zugeordnete_sektion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Mandantenliste. Der Zuordnungsstapel steht nur noch als Zähler darüber —
/// die Liste der Mandanten beginnt damit wieder oben, unabhängig davon, wie
/// viele Ordner offen sind.
///
/// Geladen wird seitenweise: in der Kanzlei stehen tausende Mandanten im
/// Register, und die alle auf einmal zu holen ist ein Abruf, den die Liste
/// nicht braucht. Die **Suche** läuft trotzdem über den ganzen Bestand — sie
/// geht in den Dienst und nicht über das gerade Geladene, sonst hinge es am
/// Scrollstand, ob ein Mandant gefunden wird.
class MandantenOverview extends StatelessWidget {
  final MandantenOverviewLoaded state;

  /// Wie nah am Ende der Liste die nächste Seite geholt wird.
  static const double nachladeAbstand = 400;

  const MandantenOverview({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.gesamtMandanten == 0 && state.akten.isEmpty) {
      return const MandantenLeererZustand();
    }

    final offen = state.offeneOrdnerAnzahl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        EntitySearchBar(
          initialQuery: state.query,
          hintText: 'Mandanten nach Name, Ort oder Ordner durchsuchen …',
          // Die Suche geht an den Dienst — jeder Tastendruck wäre ein Abruf.
          entprellung: MandantenOverviewBloc.sucheVerzoegerung,
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
          anzahl: state.gefundeneMandanten,
          gesamt: state.gesamtMandanten,
          query: state.query,
        ),
        Expanded(child: _liste(context)),
      ],
    );
  }

  Widget _liste(BuildContext context) {
    if (state.gesamtMandanten == 0) {
      return const MandantenHinweis(
        'Noch keine Mandanten gespeichert. Legen Sie über „Neuer Mandant" '
        'einen an oder ordnen Sie einen gefundenen Ordner zu.',
      );
    }
    if (state.mandanten.isEmpty) {
      return state.neuLadend
          ? const MandantenHinweis('Wird gesucht …')
          : MandantenHinweis('Kein Mandant passt zu „${state.query}".');
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (meldung) {
        _vielleichtNachladen(context, meldung.metrics);
        return false;
      },
      child: ListView.builder(
        // Eine Zeile mehr als Mandanten: der Fuß sagt, ob noch etwas kommt.
        itemCount: state.mandanten.length + 1,
        itemBuilder: (_, i) => i == state.mandanten.length
            ? MandantenListenFuss(
                geladen: state.mandanten.length,
                gesamt: state.gefundeneMandanten,
                laedt: state.mehrLadend,
              )
            : MandantCard(mandant: state.mandanten[i], state: state),
      ),
    );
  }

  /// Nachladen, sobald das Ende in Sichtweite kommt. Der Bloc verwirft, was
  /// währenddessen noch hereinkommt — der Scroll meldet sich Pixel für Pixel.
  void _vielleichtNachladen(BuildContext context, ScrollMetrics metrics) {
    if (!state.gibtWeitereMandanten || state.mehrLadend) return;
    if (metrics.pixels < metrics.maxScrollExtent - nachladeAbstand) return;
    context.read<MandantenOverviewBloc>().add(
      const LadeWeitereMandantenEvent(),
    );
  }
}
