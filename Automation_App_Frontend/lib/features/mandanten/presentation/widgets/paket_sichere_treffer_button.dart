import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/features/mandanten/domain/services/sichere_treffer.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/ordnername_vorschlag.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// „Sichere Treffer übernehmen" (Issue #108, E3) — zweiter Knopf neben
/// „Arbeitspaket holen", tonal statt gefüllt: es gibt nur eine Hauptaktion.
///
/// Baut **keinen neuen Weg**: `SichereTreffer.finde` sucht unter den offenen
/// Ordnern und dem Register, was sich ohne Nachlesen sicher zuordnen lässt,
/// `SichereTreffer.alsImportdatei` macht daraus eine `MandantenImportDatei`
/// im Arbeitsspeicher, und die geht durch den vorhandenen Import — mit
/// Vorschau, Ergänzen-nie-überschreiben und Paket-Fortschritt wie jede andere
/// Importdatei auch.
class PaketSichereTrefferButton extends StatefulWidget {
  const PaketSichereTrefferButton({super.key});

  @override
  State<PaketSichereTrefferButton> createState() =>
      _PaketSichereTrefferButtonState();
}

class _PaketSichereTrefferButtonState extends State<PaketSichereTrefferButton> {
  /// Sperrt den Knopf für die Dauer eines Laufs (Befund aus dem Code Review
  /// zu Issue #108, wie bei `PaketHolenButton`): [_uebernehmen] lädt erst das
  /// ganze Register und navigiert danach — ein Doppelklick löste sonst
  /// dieselbe Navigation zweimal aus. Anders als beim „Arbeitspaket holen"
  /// entsteht dabei keine falsche Paketnummer (hier wird keine vorhergesagt),
  /// aber derselbe unbewachte Knopf während eines mehrstufigen Ablaufs.
  bool _laeuft = false;

  @override
  Widget build(BuildContext context) {
    final aktiv =
        context.watch<MandantenOverviewBloc>().state
            is MandantenOverviewLoaded &&
        !_laeuft;
    return FilledButton.tonalIcon(
      onPressed: aktiv ? () => _uebernehmen(context) : null,
      icon: _laeuft
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome_outlined, size: 18),
      label: const Text('Sichere Treffer übernehmen'),
    );
  }

  Future<void> _uebernehmen(BuildContext context) async {
    if (_laeuft) return;
    setState(() => _laeuft = true);
    try {
      final bloc = context.read<MandantenOverviewBloc>();
      final rueckmeldung = Rueckmeldung.von(context);
      final state = bloc.state;
      if (state is! MandantenOverviewLoaded) return;

      final mandanten = await bloc.ladeAlleMandanten();
      final treffer = SichereTreffer.finde(
        offeneOrdner: state.offeneOrdnerFuerPaket,
        mandanten: mandanten,
        namensvorschlag: nameVorschlagAusOrdner,
      );

      if (treffer.isEmpty) {
        rueckmeldung.hinweis(
          'Kein Ordner lässt sich ohne Nachlesen sicher zuordnen.',
        );
        return;
      }

      final datei = SichereTreffer.alsImportdatei(treffer);
      if (!context.mounted) return;
      await context.router.push(
        MandantenImportRoute(
          vorgabe: datei,
          herkunft: 'Sichere Treffer aus ${treffer.length} Ordnern',
        ),
      );
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }
}
