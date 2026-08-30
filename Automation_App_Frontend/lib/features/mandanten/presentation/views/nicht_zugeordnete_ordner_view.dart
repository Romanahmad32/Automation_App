import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_hinweis.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/nicht_zugeordneter_ordner_kachel.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/ordner_filter_leiste.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/ordner_massenaktion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Zuordnungsstapel: alle im Stammordner gefundenen Ordner ohne Mandanten,
/// in drei Töpfe geteilt und als `ListView.builder` — im Produktivbestand sind
/// das rund 4000 Zeilen, von denen immer nur die sichtbaren gebaut werden.
class NichtZugeordneteOrdnerView extends StatelessWidget {
  final MandantenOverviewLoaded state;

  const NichtZugeordneteOrdnerView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = state.zuordnungFilter;
    final sichtbar = state.sichtbareNichtZugeordnete;
    final imTopf = state.ordnerZaehlerUngefiltert[filter.ansicht] ?? 0;
    final vermerkt = state.ohneMandantenbezug;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        OrdnerFilterLeiste(
          filter: filter,
          zaehler: state.ordnerZaehler,
          onChanged: (neu) => context.read<MandantenOverviewBloc>().add(
            SetzeZuordnungFilterEvent(neu),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${sichtbar.length} von $imTopf Ordnern in dieser Ansicht',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            OrdnerMassenaktion(sichtbar: sichtbar, ansicht: filter.ansicht),
          ],
        ),
        Expanded(
          child: sichtbar.isEmpty
              ? MandantenHinweis(_leerText(imTopf, filter.ansicht))
              : ListView.builder(
                  itemCount: sichtbar.length,
                  itemBuilder: (_, i) => NichtZugeordneterOrdnerKachel(
                    akte: sichtbar[i],
                    vermerkt: vermerkt.enthaelt(sichtbar[i].ordnername),
                  ),
                ),
        ),
        Text(
          _fussnote(filter.ansicht),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// Warum die Liste leer ist — der Unterschied zwischen „nichts mehr zu tun"
  /// und „die Filter lassen nichts durch" ist genau der, der zählt.
  String _leerText(int imTopf, OrdnerAnsicht ansicht) {
    if (imTopf > 0) return 'Kein Ordner passt zu den gesetzten Filtern.';
    return switch (ansicht) {
      OrdnerAnsicht.stapel =>
        'Der Zuordnungsstapel ist leer — jeder gefundene Ordner ist einem '
            'Mandanten zugeordnet oder als „ohne Mandantenbezug" vermerkt.',
      OrdnerAnsicht.andere =>
        'Kein Ordner deutet nach seinem Namen auf eine Bußgeld-, Straf- oder '
            'Familiensache.',
      OrdnerAnsicht.ohneBezug =>
        'Noch kein Ordner als „ohne Mandantenbezug" vermerkt.',
    };
  }

  String _fussnote(OrdnerAnsicht ansicht) => switch (ansicht) {
    OrdnerAnsicht.stapel =>
      'Ordner, die als Verkehrsunfallsache in Frage kommen — auch die ohne '
          'Aktentyp im Namen. Das ist der Arbeitsvorrat.',
    OrdnerAnsicht.andere =>
      'Nach dem Namen Bußgeld-, Straf- oder Familiensachen. Die müssen meist '
          'gar keinem Mandanten zugeordnet werden.',
    OrdnerAnsicht.ohneBezug =>
      'Entschieden: gehört keinem Mandanten. Es ist nichts gelöscht und kein '
          'Ordner angefasst — jeder Vermerk ist zurücknehmbar.',
  };
}
