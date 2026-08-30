import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/ordnername_vorschlag.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnen_dialog.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/zuordnen_ergebnis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eine Zeile des Zuordnungsstapels: ein gefundener Ordner ohne Mandanten-
/// Zuordnung, mit Aktentyp und Änderungszeitpunkt als Entscheidungshilfe und
/// dem Zuordnen-Dialog.
///
/// Bewusst schlank gehalten — die Kachel wird in einer `ListView.builder` mit
/// mehreren tausend Einträgen gebaut. Die Fälle der Akte stehen hier deshalb
/// nicht: sie zu zählen hieße, den ganzen Unterbaum zu lesen.
class NichtZugeordneterOrdnerKachel extends StatelessWidget {
  final Akte akte;

  /// Auswahl für den Zuordnen-Dialog.
  final List<Mandant> mandanten;

  /// Ob für diesen Ordner schon entschieden ist, dass er keinem Mandanten
  /// gehört. Bestimmt die Richtung der zweiten Aktion.
  final bool vermerkt;

  const NichtZugeordneterOrdnerKachel({
    super.key,
    required this.akte,
    required this.mandanten,
    this.vermerkt = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(Icons.folder_off_outlined, color: scheme.outline),
      title: Text(akte.ordnername),
      subtitle: Text(
        _untertitel(),
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _zuordnen(context),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Zuordnen'),
          ),
          IconButton(
            onPressed: () => _vermerken(context),
            icon: Icon(vermerkt ? Icons.undo : Icons.block_outlined, size: 18),
            tooltip: vermerkt
                ? 'Vermerk zurücknehmen — zurück in den Stapel'
                : 'Gehört keinem Mandanten',
          ),
        ],
      ),
    );
  }

  /// Die Einzelfall-Entscheidung neben der Massenaktion: für die Ordner, die
  /// die Aktentyp-Heuristik falsch einsortiert hat.
  void _vermerken(BuildContext context) {
    context.read<MandantenOverviewBloc>().add(
      SetzeOrdnerStatusEvent(
        ordnernamen: [akte.ordnername],
        art: vermerkt ? null : OrdnerStatusArt.ohneMandantenbezug,
      ),
    );
  }

  String _untertitel() {
    final geaendert = akte.geaendertAm;
    final typ = akte.aktentyp.bezeichnung;
    return geaendert == null ? typ : '$typ · geändert am ${_datum(geaendert)}';
  }

  String _datum(DateTime wert) {
    String zwei(int n) => n.toString().padLeft(2, '0');
    return '${zwei(wert.day)}.${zwei(wert.month)}.${wert.year}';
  }

  Future<void> _zuordnen(BuildContext context) async {
    final bloc = context.read<MandantenOverviewBloc>();
    final router = context.router;
    final auswahl = await showDialog<ZuordnenErgebnis>(
      context: context,
      builder: (_) =>
          ZuordnenDialog(ordnername: akte.ordnername, mandanten: mandanten),
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
      // Nur das Register neu holen: am Dateisystem hat sich nichts geändert,
      // und ein erneuter Scan wäre bei tausenden Ordnern der teure Teil.
      if (didChange == true) {
        bloc.add(const LoadMandantenUebersichtEvent(nurRegister: true));
      }
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
