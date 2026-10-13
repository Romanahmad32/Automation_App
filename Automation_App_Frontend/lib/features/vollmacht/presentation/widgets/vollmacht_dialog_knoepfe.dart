import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Knöpfe des Vollmacht-Dialogs je Phase (§4.11).
///
/// Beim Ausfüllen: „Drucken" ist der Normalfall und steht rechts, „In Word
/// öffnen" der Rückfall daneben; ohne eingerichteten Drucker bleibt nur der
/// Rückfall. Im Ergebnis: nur „Fertig".
///
/// Ist eine Word-Fassung geöffnet, heißt „Abbrechen" „Schließen" (#174): Es
/// gibt dann etwas, das nicht abgebrochen, sondern ohne Vermerk
/// zurückgelassen wird — die Frage danach steht in der Word-Leiste darüber.
/// Derselbe „In Word öffnen" öffnet die Datei noch einmal.
class VollmachtDialogKnoepfe extends StatelessWidget {
  final VollmachtStand stand;

  const VollmachtDialogKnoepfe({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VollmachtCubit>();
    final schliessen = Navigator.of(context).pop;

    final knoepfe = switch (stand.phase) {
      // Nachsteuern („Erneut drucken" usw.) sitzt in der Ergebnisansicht.
      VollmachtPhase.abgeschlossen => [
        FilledButton(onPressed: schliessen, child: const Text('Fertig')),
      ],
      _ => [
        TextButton(
          onPressed: stand.phase == VollmachtPhase.eingabe ? schliessen : null,
          child: Text(stand.wordFassung == null ? 'Abbrechen' : 'Schließen'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('In Word öffnen'),
          onPressed: stand.bereit ? cubit.oeffneInWord : null,
        ),
        FilledButton.icon(
          icon: const Icon(Icons.print_outlined),
          label: const Text('Drucken'),
          onPressed: stand.druckbereit ? cubit.drucke : null,
        ),
      ],
    };

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: knoepfe,
    );
  }
}
