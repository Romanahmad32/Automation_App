import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_hinweis.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/mandanten_listen_fuss.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/nicht_zugeordneter_ordner_kachel.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/ordner_filter_leiste.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/ordner_massenaktion.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/stand_karte.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnung_ablauf_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Zuordnungsstapel: alle im Stammordner gefundenen Ordner ohne Mandanten,
/// in drei Töpfe geteilt und in einem `CustomScrollView` — im Produktivbestand
/// sind das rund 4000 Zeilen, von denen immer nur die sichtbaren gebaut
/// werden. Kopf und Liste teilen sich **eine** Scrollleiste, statt dass der
/// Kopf eine feste Höhe bekommt: ein aufgeklapptes Band (Ablauf-Hinweis,
/// Paket-Historie) schiebt die Liste dann einfach nach unten, statt das Fenster
/// zu sprengen — ein `Column` mit `Expanded` lief hier über, sobald Kopf und
/// Liste zusammen nicht mehr in die Fensterhöhe passten.
class NichtZugeordneteOrdnerView extends StatelessWidget {
  /// Wie früh vor dem Listenende die nächste Portion angefordert wird.
  static const double nachladeAbstand = 400;

  final MandantenOverviewLoaded state;

  const NichtZugeordneteOrdnerView({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = state.zuordnungFilter;
    // Alle passenden Ordner — für „N von M" und für die Massenaktion, die
    // ausdrücklich auf dem ganzen gefilterten Topf arbeitet und nicht nur auf
    // dem, was gerade zu sehen ist.
    final sichtbar = state.sichtbareNichtZugeordnete;
    final angezeigt = state.angezeigteNichtZugeordnete;
    final imTopf = state.ordnerZaehlerUngefiltert[filter.ansicht] ?? 0;
    final vermerkt = state.ohneMandantenbezug;

    return NotificationListener<ScrollNotification>(
      onNotification: (meldung) {
        _vielleichtMehrZeigen(context, meldung.metrics);
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  // Bleibt immer da — nur zugeklappt, sobald schon ein Paket
                  // geholt wurde. Ein ganz verschwindendes Band verlässt sich
                  // auf einen Datenbankzustand als Beweis für „hat es schon
                  // einmal gesehen", und genau das ging in der Praxis daneben:
                  // ein einzelnes Testpaket aus einer früheren Sitzung reichte,
                  // um die Erklärung dauerhaft unsichtbar zu machen.
                  ZuordnungAblaufHinweis(
                    anfangsOffen: state.importPakete.isEmpty,
                  ),
                  StandKarte(
                    gesamt: state.gesamtOrdnerAnzahl,
                    zugeordnet: state.zugeordneteOrdnerAnzahl,
                    ohneBezug: state.ohneBezugOrdnerAnzahl,
                    offen: state.offeneOrdnerAnzahl,
                    pakete: state.importPakete,
                    onPaketLoeschen: (nummer) =>
                        _paketLoeschen(context, nummer),
                  ),
                  OrdnerFilterLeiste(
                    filter: filter,
                    zaehler: state.ordnerZaehler,
                    herkunft: state.stapelHerkunft,
                    onChanged: (neu) => context
                        .read<MandantenOverviewBloc>()
                        .add(SetzeZuordnungFilterEvent(neu)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${sichtbar.length} von $imTopf Ordnern in dieser '
                          'Ansicht',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      OrdnerMassenaktion(
                        sichtbar: sichtbar,
                        ansicht: filter.ansicht,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (sichtbar.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: MandantenHinweis(_leerText(imTopf, filter.ansicht)),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => NichtZugeordneterOrdnerKachel(
                  akte: angezeigt[i],
                  vermerkt: vermerkt.enthaelt(angezeigt[i].ordnername),
                ),
                childCount: angezeigt.length,
              ),
            ),
          if (state.gibtWeitereOrdner)
            SliverToBoxAdapter(
              child: MandantenListenFuss(
                geladen: angezeigt.length,
                gesamt: sichtbar.length,
                laedt: false,
                meldung:
                    '${angezeigt.length} von ${sichtbar.length} Ordnern '
                    'angezeigt — weiterscrollen zeigt mehr.',
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _fussnote(filter.ansicht),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Die nächste Portion zeigen, sobald das Ende in Sichtweite kommt. Anders
  /// als bei der Mandantenliste wird dabei nichts geholt — die Ordner liegen
  /// seit dem Scan alle vor, es wächst nur der gezeigte Ausschnitt.
  void _vielleichtMehrZeigen(BuildContext context, ScrollMetrics metrics) {
    if (!state.gibtWeitereOrdner) return;
    if (metrics.pixels < metrics.maxScrollExtent - nachladeAbstand) return;
    context.read<MandantenOverviewBloc>().add(const ZeigeWeitereOrdnerEvent());
  }

  /// Nimmt ein offenes Paket zurück und meldet Erfolg oder Grund der
  /// Ablehnung (z. B. ein inzwischen eingelesenes Paket) über [Rueckmeldung].
  Future<void> _paketLoeschen(BuildContext context, int nummer) async {
    final bloc = context.read<MandantenOverviewBloc>();
    final rueckmeldung = Rueckmeldung.von(context);
    final ergebnis = await bloc.loescheImportPaket(nummer);
    switch (ergebnis) {
      case Right():
        rueckmeldung.erfolg('Paket $nummer zurückgenommen.');
      case Left(value: final failure):
        rueckmeldung.fehler(failure.message);
    }
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
