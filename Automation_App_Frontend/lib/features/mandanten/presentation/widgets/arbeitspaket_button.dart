import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/arbeitspaket_cubit/arbeitspaket_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/arbeitspaket_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Holt das nächste Arbeitspaket und legt es als Datei ab.
///
/// Steht in der Kopfzeile **vor** „Aus Datei übernehmen", weil das die
/// Reihenfolge des Vorgangs ist: erst holen, dann bearbeiten lassen, dann
/// übernehmen.
class ArbeitspaketButton extends StatelessWidget {
  const ArbeitspaketButton({super.key});

  @override
  Widget build(BuildContext context) {
    final laufend = context.select<ArbeitspaketCubit, bool>(
      (cubit) => cubit.state.laufend,
    );
    // Denselben Weg geht der Nachbar `ImportOeffnenButton`: Die Kopfzeile liegt
    // innerhalb der BlocProvider der Seite, aber außerhalb des
    // Zustandsbereichs, der die geladenen Daten aufbereitet.
    final stand = context.watch<MandantenOverviewBloc>().state;
    final geladen = stand is MandantenOverviewLoaded ? stand : null;
    final offen = geladen?.offeneOrdnerAnzahl ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton.icon(
        onPressed: (laufend || geladen == null || offen == 0)
            ? null
            : () => _holen(context, geladen, offen),
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
        label: const Text('Arbeitspaket holen'),
      ),
    );
  }

  Future<void> _holen(
    BuildContext context,
    MandantenOverviewLoaded stand,
    int offen,
  ) async {
    final anzahl = await showDialog<int>(
      context: context,
      builder: (_) => ArbeitspaketDialog(offen: offen),
    );
    if (anzahl == null || !context.mounted) return;

    // Nur der Ordner: Wie die Datei heißt, steht erst fest, wenn der Dienst
    // die Paketnummer vergeben hat.
    final ordner = await FilePicker.getDirectoryPath(
      dialogTitle: 'Ordner für das Arbeitspaket wählen',
    );
    if (ordner == null || !context.mounted) return;

    final cubit = context.read<ArbeitspaketCubit>();
    final rueckmeldung = Rueckmeldung.von(context);
    final paket = await cubit.holeUndSchreibe(
      // Alle gescannten Ordner: welche davon offen sind, entscheidet der
      // Dienst — er führt die Zuordnungen und die Vermerke.
      ordnernamen: [for (final akte in stand.akten) akte.ordnername],
      anzahl: anzahl,
      zielPfad: ordner,
      mandanten: stand.mandanten,
    );

    if (paket != null) {
      rueckmeldung.erfolg(
        'Arbeitspaket ${paket.nummer} mit ${paket.ordnerAnzahl} Ordnern '
        'gespeichert: ${ArbeitspaketCubit.dateipfadIn(ordner, paket)}',
      );
      return;
    }
    // Kein offener Ordner mehr ist der Abschluss der Übung, keine Störung —
    // eine rote Meldung dafür meldete dem Anwalt einen Defekt, wo er fertig
    // ist.
    if (cubit.state.nichtsOffen) {
      rueckmeldung.hinweis(
        'Es ist kein Ordner mehr offen — es gibt nichts zu holen.',
      );
      return;
    }
    final fehler = cubit.state.fehler;
    if (fehler != null) rueckmeldung.fehler(fehler);
  }
}
