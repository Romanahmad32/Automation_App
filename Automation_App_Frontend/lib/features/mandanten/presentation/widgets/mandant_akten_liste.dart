import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/core/general_widgets/form/hinzufuegen_button.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/akte_block.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/akte_zuordnen_dialog.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/nicht_gefundener_ordner_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Akten in der aufgeklappten `MandantCard`: gefundene, nicht mehr
/// gefundene, und darunter „Akte zuordnen …" (#132).
///
/// Zuordnen und Lösen gab es vorher nur aus der Gegenrichtung, im
/// Zuordnungsstapel. Wer beim Mandanten stand und wusste, welcher Ordner ihm
/// gehört, musste die Seite wechseln — und fand dort weder beiseitegelegte
/// noch fremd zugeordnete Ordner.
class MandantAktenListe extends StatelessWidget {
  final Mandant mandant;
  final MandantenOverviewLoaded state;

  const MandantAktenListe({
    super.key,
    required this.mandant,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final akten = state.aktenFuer(mandant);
    final nichtGefunden = state.nichtGefundeneOrdnerFuer(mandant);
    final hinweis = mandant.aktenOrdnernamen.isEmpty
        ? 'Noch keine Akte zugeordnet.'
        : state.akten.isEmpty
        ? 'Der Akten-Stammordner ist leer oder nicht erreichbar — die '
              'zugeordneten Ordner lassen sich nicht prüfen.'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hinweis != null)
          Text(
            hinweis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        for (final akte in akten)
          AkteBlock(
            akte: akte,
            onLoesen: () => _loesen(context, akte.ordnername),
          ),
        for (final ordnername in nichtGefunden)
          NichtGefundenerOrdnerBlock(
            ordnername: ordnername,
            onLoesen: () => _loesen(context, ordnername),
          ),
        const SizedBox(height: 12),
        // Ohne gescannte Ordner gibt es nichts zu wählen — ein Dialog mit
        // leerer Liste wäre die Auskunft, die der Hinweis darüber schon gibt.
        HinzufuegenButton(
          beschriftung: 'Akte zuordnen …',
          onHinzufuegen: state.akten.isEmpty ? null : () => _zuordnen(context),
        ),
      ],
    );
  }

  String get _name =>
      mandant.anzeigename.isEmpty ? '(ohne Namen)' : mandant.anzeigename;

  Future<void> _zuordnen(BuildContext context) async {
    final bloc = context.read<MandantenOverviewBloc>();
    final ordnername = await showDialog<String>(
      context: context,
      builder: (_) => AkteZuordnenDialog(
        mandantName: _name,
        eintraege: state.aktenAuswahlFuer(mandant),
      ),
    );
    if (ordnername == null) return;

    bloc.add(
      VerknuepfeOrdnerEvent(mandantId: mandant.id, ordnername: ordnername),
    );
    // Die Karte ist aufgeklappt, ihre Fälle hat sie beim Aufklappen gelesen —
    // die der neuen Akte nicht. Ohne das stünde dort „Fälle werden gelesen …",
    // bis jemand die Karte zu- und wieder aufklappt.
    for (final akte in state.akten) {
      if (akte.ordnername == ordnername) bloc.add(LadeFaelleEvent(akte));
    }
  }

  Future<void> _loesen(BuildContext context, String ordnername) async {
    final bloc = context.read<MandantenOverviewBloc>();
    final bestaetigt = await bestaetigen(
      context,
      icon: Icons.link_off,
      titel: 'Zuordnung lösen?',
      text:
          'Der Ordner „$ordnername" gehört danach nicht mehr zu $_name. '
          'Im Dateisystem bleibt er unberührt und steht wieder im '
          'Zuordnungsstapel.',
      bestaetigung: 'Lösen',
    );
    if (!bestaetigt) return;
    bloc.add(LoeseOrdnerEvent(mandantId: mandant.id, ordnername: ordnername));
  }
}
