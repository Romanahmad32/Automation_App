import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Knöpfe des Vollmacht-Dialogs je Phase (§4.11).
///
/// Beim Ausfüllen: „Drucken" ist der Normalfall und steht rechts, „In Word
/// öffnen" der Rückfall daneben; ohne eingerichteten Drucker bleibt nur der
/// Rückfall. Im Ergebnis: nur „Fertig". Nach dem Öffnen in Word: die Rückfrage, ob
/// der Druck vermerkt werden soll — „Ohne Vermerk schließen" ist bewusst eine
/// gleichwertige Antwort, die App weiß ja nicht, ob Papier herauskam.
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
      VollmachtPhase.inWordGeoeffnet => [
        TextButton(
          onPressed: schliessen,
          child: const Text('Ohne Vermerk schließen'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.task_alt),
          label: const Text('Als gedruckt vermerken'),
          onPressed: cubit.vermerkeAlsGedruckt,
        ),
      ],
      _ => [
        TextButton(
          onPressed: stand.phase == VollmachtPhase.eingabe ? schliessen : null,
          child: const Text('Abbrechen'),
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
